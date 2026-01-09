//
//  AppState.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import SwiftUI
import AVFoundation

/// Central state machine for the Loqui app
/// This orchestrates the entire speech-to-text pipeline
@MainActor
class AppState: ObservableObject {
    // MARK: - Singleton
    static let shared = AppState()

    // MARK: - State Enum
    enum State {
        case idle
        case recording(startTime: Date)
        case processing
        case error(Error)
    }

    // MARK: - Published Properties
    @Published var currentState: State = .idle
    @Published var statusText: String = "Idle"
    @Published var currentModel: String = "Not loaded"
    @Published var modelsReady: Bool = false  // Track model initialization state

    // MARK: - Computed Properties
    var hasAPIKeys: Bool {
        // Check UserDefaults directly to avoid race condition with async initialization
        let groqKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        let openaiKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
        return !groqKey.isEmpty || !openaiKey.isEmpty
    }

    // MARK: - Core Components
    private var fnKeyMonitor: FnKeyMonitor?

    // MARK: - Audio Pipeline (Phase 2)
    private var audioCapture: WhisperAudioCapture?
    private var audioBuffer: Data = Data()

    // MARK: - Transcription (Phase 3)
    private var transcriptionEngine: TranscriptionEngine?

    // MARK: - LLM (Phase 4 - Cloud API)
    private var groqClient: GroqClient?
    private var openaiClient: OpenAIClient?

    // MARK: - Text Insertion (Phase 5)
    private var textInserter: TextInserter?
    private var hudController: HUDWindowController?

    // MARK: - Initialization
    private init() {
        print("🚀 AppState: Initializing...")
        // Note: HUD is created lazily to avoid circular dependency
        // (HUDViewModel observes AppState.shared, so can't create during init)
    }

    // MARK: - fn Key Monitoring
    func startKeyMonitoring() -> Result<Void, FnKeyMonitorError> {
        // Initialize HUD now (after AppState.shared initialization complete)
        // This avoids circular dependency that would occur in init()
        if hudController == nil {
            hudController = HUDWindowController()
            print("✅ AppState: HUD initialized")
        }

        fnKeyMonitor = FnKeyMonitor()
        let result = fnKeyMonitor?.start() ?? .failure(.eventTapCreationFailed)

        // Only set up notification observers if monitoring started successfully
        guard case .success = result else {
            print("❌ AppState: fn key monitoring failed to start")
            return result
        }

        // Listen for fn key press events
        NotificationCenter.default.addObserver(
            forName: .fnKeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startRecording()
        }

        // Listen for fn key release events
        NotificationCenter.default.addObserver(
            forName: .fnKeyReleased,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopRecording()
        }

        print("✅ AppState: fn key monitoring started")
        return .success(())
    }

    // MARK: - Recording Control
    func startRecording() {
        // Block if already processing
        guard case .idle = currentState else {
            print("⚠️  AppState: Cannot start recording - currently \(currentState)")
            // TODO: Show notification "Still processing previous transcription"
            return
        }

        // Check microphone permission first
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized {
            print("🎤 AppState: Microphone permission not granted, requesting...")

            // Request microphone permission
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ AppState: Microphone permission granted")
                        // Retry recording now that we have permission
                        self?.startRecording()
                    } else {
                        print("❌ AppState: Microphone permission denied")
                        self?.showMicrophonePermissionAlert()
                    }
                }
            }
            return
        }

        // Check if any API key is configured
        if !hasAPIKeys {
            print("⚠️  AppState: No API keys configured")
            showAPIKeyRequiredAlert()
            return
        }

        // Check if models are ready (prevents 131s hang on first transcription)
        if !modelsReady {
            print("⚠️  AppState: Models not ready yet, showing loading HUD")
            Task { await setHUDLoadingState() }
            return
        }

        currentState = .recording(startTime: Date())
        statusText = "Recording..."
        print("🎤 AppState: Recording started")

        // Phase 2: Initialize audio capture
        audioBuffer = Data()
        audioCapture = WhisperAudioCapture()
        audioCapture?.onAudioChunk = { [weak self] chunk in
            self?.audioBuffer.append(chunk)
        }

        do {
            try audioCapture?.startCapture()
        } catch {
            LoquiLogger.shared.logError(error, context: "Audio capture start")
            print("❌ AppState: Failed to start audio capture: \(error)")

            // Return to idle so user can try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.currentState = .idle
                self?.statusText = "Idle"
            }

            currentState = .error(error)
            statusText = "Error"
            return
        }

        // Phase 5: Initialize text inserter
        if textInserter == nil {
            textInserter = TextInserter()
        }

        // Floater automatically updates via state observation
    }

    func stopRecording() {
        guard case .recording = currentState else {
            return
        }

        print("🛑 AppState: Recording stopped")
        print("📊 AppState: Audio buffer size: \(audioBuffer.count) bytes")

        // Phase 2: Stop audio capture
        audioCapture?.stopCapture()

        // Floater automatically updates via state observation

        // Transition to processing state
        currentState = .processing
        statusText = "Processing transcription..."

        // Phase 2: Process recording
        Task {
            await processRecording()
        }
    }

    // MARK: - Model Initialization (Phase 3 & 4)
    func initializeModels() async {
        statusText = "Loading models..."
        print("📦 AppState: Initializing models...")

        // Show HUD in loading state (visible to user during 131s model load)
        await setHUDLoadingState()

        do {
            // Phase 3: Initialize Whisper
            transcriptionEngine = TranscriptionEngine()
            try await transcriptionEngine?.initialize()

            currentModel = "distil-large-v3 (594MB)"
            print("✅ AppState: Whisper model loaded")

            // Phase 4: Initialize Cloud LLM
            var llmProviders: [String] = []

            if let apiKey = UserDefaults.standard.string(forKey: "groqAPIKey"), !apiKey.isEmpty {
                groqClient = GroqClient(apiKey: apiKey)
                llmProviders.append("Groq")
                print("✅ AppState: Groq client initialized")
            } else {
                print("⚠️  AppState: No Groq API key configured")
            }

            if let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"), !apiKey.isEmpty {
                openaiClient = OpenAIClient(apiKey: apiKey)
                llmProviders.append("OpenAI")
                print("✅ AppState: OpenAI client initialized")
            } else {
                print("⚠️  AppState: No OpenAI API key configured")
            }

            if !llmProviders.isEmpty {
                currentModel = "Whisper + \(llmProviders.joined(separator: " + "))"
            } else {
                currentModel = "Whisper (No LLM - Configure API key in Settings)"
            }

            // Mark models as ready
            modelsReady = true
            print("✅ AppState: All models loaded and ready")

        } catch {
            LoquiLogger.shared.logError(error, context: "Model initialization")
            print("❌ AppState: Model initialization failed: \(error)")
            currentModel = "Model load failed"
            modelsReady = false  // Keep as not ready on failure
        }

        // Hide HUD after loading complete
        await clearHUDLoadingState()

        statusText = "Idle"
    }

    // MARK: - Processing Pipeline (Phase 2-5)
    private func processRecording() async {
        let pipelineStart = Date()
        print("⏱️  [0.00s] Pipeline started")

        do {
            // Phase 2: VAD analysis
            let vadStart = Date()
            let vadProcessor = try await VADProcessor()
            let vadResult = try await vadProcessor.analyzeRecording(audioBuffer)
            let vadTime = Date().timeIntervalSince(vadStart)
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] VAD complete (\(String(format: "%.2f", vadTime))s)")

            guard case .speech(let trimmedAudio) = vadResult else {
                print("❌ AppState: No speech detected")
                currentState = .idle
                statusText = "Idle"
                // TODO Phase 5: Show notification "No speech detected"
                return
            }

            print("✅ AppState: Speech detected, \(trimmedAudio.count) bytes after trimming")

            // Phase 3: Transcription
            let whisperStart = Date()
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Whisper transcription started")
            guard let rawText = try await transcriptionEngine?.transcribe(trimmedAudio) else {
                throw TranscriptionError.notInitialized
            }
            let whisperTime = Date().timeIntervalSince(whisperStart)
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Whisper complete (\(String(format: "%.2f", whisperTime))s)")
            print("📝 Transcription: '\(rawText)'")

            // Phase 4: Command processing
            let commandStart = Date()
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Command processing started")
            let commandProcessor = CommandProcessor()
            let commandProcessedText = try await commandProcessor.processCommands(
                transcript: rawText,
                llmClient: groqClient
            )
            let commandTime = Date().timeIntervalSince(commandStart)
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Commands complete (\(String(format: "%.3f", commandTime))s)")

            // Phase 5: Enhanced cleanup with vocabulary
            let cleanupStart = Date()
            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Enhanced cleanup started")
            let cleanupProcessor = CleanupProcessor()
            let vocabulary = VocabularyManager.shared.vocabulary
            var finalText = commandProcessedText

            // Try Groq first (primary provider)
            if let groqClient = groqClient {
                do {
                    finalText = try await cleanupProcessor.clean(
                        text: commandProcessedText,
                        vocabulary: vocabulary,
                        llmClient: groqClient
                    )
                    let cleanupTime = Date().timeIntervalSince(cleanupStart)
                    print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Cleanup complete (Groq: \(String(format: "%.3f", cleanupTime))s)")
                    print("✨ Enhanced Cleaned: '\(commandProcessedText)' → '\(finalText)'")
                } catch let error as LLMError {
                    let cleanupTime = Date().timeIntervalSince(cleanupStart)
                    print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Groq failed (\(String(format: "%.3f", cleanupTime))s)")
                    print("⚠️  Groq cleanup failed: \(error.localizedDescription)")

                    // Try OpenAI fallback
                    if let openaiClient = openaiClient {
                        print("🔷 Attempting OpenAI fallback...")
                        let openaiStart = Date()
                        do {
                            finalText = try await cleanupProcessor.clean(
                                text: commandProcessedText,
                                vocabulary: vocabulary,
                                llmClient: openaiClient
                            )
                            let openaiTime = Date().timeIntervalSince(openaiStart)
                            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Cleanup complete (OpenAI: \(String(format: "%.3f", openaiTime))s)")
                            print("✨ Enhanced Cleaned (OpenAI fallback): '\(commandProcessedText)' → '\(finalText)'")
                        } catch {
                            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] OpenAI also failed")
                            print("⚠️  Both providers failed, using command-processed text")
                        }
                    } else {
                        print("⚠️  No OpenAI fallback available, using command-processed text")
                    }
                } catch {
                    let cleanupTime = Date().timeIntervalSince(cleanupStart)
                    print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Groq failed (\(String(format: "%.3f", cleanupTime))s)")
                    print("⚠️  Groq cleanup failed: \(error)")

                    // Try OpenAI fallback
                    if let openaiClient = openaiClient {
                        print("🔷 Attempting OpenAI fallback...")
                        let openaiStart = Date()
                        do {
                            finalText = try await cleanupProcessor.clean(
                                text: commandProcessedText,
                                vocabulary: vocabulary,
                                llmClient: openaiClient
                            )
                            let openaiTime = Date().timeIntervalSince(openaiStart)
                            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Cleanup complete (OpenAI: \(String(format: "%.3f", openaiTime))s)")
                            print("✨ Enhanced Cleaned (OpenAI fallback): '\(commandProcessedText)' → '\(finalText)'")
                        } catch {
                            print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] OpenAI also failed")
                            print("⚠️  Both providers failed, using command-processed text")
                        }
                    } else {
                        print("⚠️  No OpenAI fallback available, using command-processed text")
                    }
                }
            } else if let openaiClient = openaiClient {
                // No Groq, try OpenAI directly
                print("⚠️  No Groq client configured, trying OpenAI...")
                do {
                    finalText = try await cleanupProcessor.clean(
                        text: commandProcessedText,
                        vocabulary: vocabulary,
                        llmClient: openaiClient
                    )
                    let cleanupTime = Date().timeIntervalSince(cleanupStart)
                    print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Cleanup complete (OpenAI: \(String(format: "%.3f", cleanupTime))s)")
                    print("✨ Enhanced Cleaned: '\(commandProcessedText)' → '\(finalText)'")
                } catch {
                    print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] OpenAI failed")
                    print("⚠️  OpenAI cleanup failed, using command-processed text")
                }
            } else {
                let cleanupTime = Date().timeIntervalSince(cleanupStart)
                print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Cleanup skipped (no API keys) (\(String(format: "%.3f", cleanupTime))s)")
                print("⚠️  No LLM clients configured, using command-processed text")
            }

            // Phase 6: Insert text
            let insertStart = Date()
            do {
                try textInserter?.insertText(finalText)
                let insertTime = Date().timeIntervalSince(insertStart)
                print("⏱️  [\(String(format: "%.2f", Date().timeIntervalSince(pipelineStart)))s] Text insertion complete (\(String(format: "%.3f", insertTime))s)")
                print("✅ AppState: Text inserted successfully")
            } catch {
                LoquiLogger.shared.logError(error, context: "Text insertion")
                print("❌ AppState: Text insertion failed: \(error)")
                // TODO Phase 5: Show error notification to user
                // For now, just log the error
            }

            // Note: LLM cleanup failures are handled by HUD error state
            // Raw transcription already inserted above, error shown in HUD for 2s

            let totalTime = Date().timeIntervalSince(pipelineStart)
            print("⏱️  ⏱️  ⏱️  TOTAL PIPELINE LATENCY: \(String(format: "%.2f", totalTime))s")
            print("✅ AppState: Phase 5 complete - final text: '\(finalText)'")

        } catch {
            LoquiLogger.shared.logError(error, context: "Recording processing")
            print("❌ AppState: Processing error: \(error)")
            currentState = .error(error)
            statusText = "Error"

            // TODO Phase 5: Show error notification to user

            // Return to idle after 2 seconds so user can try again
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        // Always return to idle (either after success or after error delay)
        currentState = .idle
        statusText = "Idle"
        print("🔄 AppState: Returned to idle state")
    }

    // MARK: - Helper Functions
    private func showAPIKeyRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "API Key Required"
            alert.informativeText = "Please configure your Groq or OpenAI API key in Settings (Cmd+,) before using Loqui."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showMicrophonePermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Microphone Permission Required"
            alert.informativeText = "Loqui needs microphone access to transcribe your speech. Please enable it in System Settings > Privacy & Security > Microphone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Open System Settings to Microphone pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - HUD Loading State Management
    /// Show HUD in loading state (called during model initialization)
    private func setHUDLoadingState() async {
        await MainActor.run {
            hudController?.setLoadingState()
            hudController?.show()
            print("✅ AppState: HUD set to loading state")
        }
    }

    /// Clear HUD loading state and return to waiting (called after model initialization)
    private func clearHUDLoadingState() async {
        await MainActor.run {
            // Don't hide - transition to waiting state (ambient presence)
            hudController?.setWaitingState()
            print("✅ AppState: HUD loading state cleared, returned to waiting")
        }
    }

    // MARK: - Cleanup
    func cleanup() {
        fnKeyMonitor?.stop()
        audioCapture?.stopCapture()
        print("🧹 AppState: Cleanup complete")
    }
}
