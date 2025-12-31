//
//  AppState.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import SwiftUI

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

    // MARK: - Core Components
    private var fnKeyMonitor: FnKeyMonitor?

    // MARK: - Audio Pipeline (Phase 2)
    private var audioCapture: WhisperAudioCapture?
    private var audioBuffer: Data = Data()

    // MARK: - Transcription (Phase 3)
    private var transcriptionEngine: TranscriptionEngine?

    // MARK: - LLM (Phase 4)
    private var speechCleaner: SpeechCleaner?

    // MARK: - Text Insertion (Phase 5)
    // private var textInserter: TextInserter?
    // private var hudWindow: HUDWindowController?

    // MARK: - Initialization
    private init() {
        print("🚀 AppState: Initializing...")
    }

    // MARK: - fn Key Monitoring
    func startKeyMonitoring() {
        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor?.start()

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
    }

    // MARK: - Recording Control
    func startRecording() {
        // Block if already processing
        guard case .idle = currentState else {
            print("⚠️  AppState: Cannot start recording - currently \(currentState)")
            // TODO: Show notification "Still processing previous transcription"
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

        // TODO Phase 5: Show HUD window
        // hudWindow = HUDWindowController()
        // hudWindow?.show()
    }

    func stopRecording() {
        guard case .recording = currentState else {
            return
        }

        print("🛑 AppState: Recording stopped")
        print("📊 AppState: Audio buffer size: \(audioBuffer.count) bytes")

        // Phase 2: Stop audio capture
        audioCapture?.stopCapture()

        // TODO Phase 5: Hide HUD window
        // hudWindow?.hide()

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

        do {
            // Phase 3: Initialize Whisper
            transcriptionEngine = TranscriptionEngine()
            try await transcriptionEngine?.initialize()

            currentModel = "distil-large-v3 (594MB)"
            print("✅ AppState: Whisper model loaded")

            // Phase 4: Initialize LLM
            speechCleaner = SpeechCleaner()
            try await speechCleaner?.initialize()

            currentModel = "Whisper + Qwen3-4B (~5.5GB)"
            print("✅ AppState: LLM model loaded")

        } catch {
            LoquiLogger.shared.logError(error, context: "Model initialization")
            print("❌ AppState: Model initialization failed: \(error)")
            currentModel = "Model load failed"
        }

        statusText = "Idle"
    }

    // MARK: - Processing Pipeline (Phase 2-5)
    private func processRecording() async {
        do {
            // Phase 2: VAD analysis
            let vadProcessor = try await VADProcessor()
            let vadResult = try await vadProcessor.analyzeRecording(audioBuffer)

            guard case .speech(let trimmedAudio) = vadResult else {
                print("❌ AppState: No speech detected")
                currentState = .idle
                statusText = "Idle"
                // TODO Phase 5: Show notification "No speech detected"
                return
            }

            print("✅ AppState: Speech detected, \(trimmedAudio.count) bytes after trimming")

            // Phase 3: Transcription
            guard let rawText = try await transcriptionEngine?.transcribe(trimmedAudio) else {
                throw TranscriptionError.notInitialized
            }
            print("📝 Transcription: '\(rawText)'")

            // Phase 4: LLM cleanup (with fallback to raw transcription)
            var finalText = rawText
            if let cleanedText = try? await speechCleaner?.clean(rawText) {
                finalText = cleanedText
                print("✨ LLM Cleaned: '\(rawText)' → '\(finalText)'")
            } else {
                print("⚠️  LLM cleanup failed, using raw transcription")
            }

            // TODO Phase 5: Insert text
            // textInserter?.insertText(finalText)

            // For Phase 4, log the final text
            print("✅ AppState: Phase 4 complete - final text: '\(finalText)'")

        } catch {
            LoquiLogger.shared.logError(error, context: "Recording processing")
            print("❌ AppState: Processing error: \(error)")
            currentState = .error(error)
            statusText = "Error"
            return
        }

        // Return to idle
        currentState = .idle
        statusText = "Idle"
    }

    // MARK: - Cleanup
    func cleanup() {
        fnKeyMonitor?.stop()
        audioCapture?.stopCapture()
        print("🧹 AppState: Cleanup complete")
    }
}
