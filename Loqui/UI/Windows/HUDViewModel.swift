//
//  HUDViewModel.swift
//  Loqui
//
//  State management for HUD with timer coordination and error auto-dismiss
//  Observes AppState and maps to HUDState
//

import Foundation
import SwiftUI
import Combine

/// View model for HUD state management and timer coordination
@MainActor
class HUDViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentState: HUDState = .waiting

    // MARK: - Private State
    private var errorDismissTimer: Timer?
    private var transcriptionTimeoutTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupAppStateObserver()
        print("✅ HUDViewModel: Initialized")
    }

    // MARK: - AppState Observation
    private func setupAppStateObserver() {
        AppState.shared.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] appState in
                self?.handleAppStateChange(appState)
            }
            .store(in: &cancellables)
    }

    private func handleAppStateChange(_ appState: AppState.State) {
        print("🔄 HUDViewModel: AppState changed to \\(appState)")

        // Cancel any pending timers
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
        transcriptionTimeoutTimer?.invalidate()
        transcriptionTimeoutTimer = nil

        switch appState {
        case .idle:
            currentState = .waiting

        case .recording(let startTime):
            currentState = .recording(startTime: startTime)

        case .processing:
            currentState = .transcribing
            startTranscriptionTimeout()

        case .error(let error):
            let message = mapErrorMessage(error)
            currentState = .error(message: message, duration: 2.0)
            startErrorDismissTimer()
        }
    }

    // MARK: - Timer Management

    /// Start transcription timeout timer
    /// Smart timeout: 180s first-run, 5s normal
    private func startTranscriptionTimeout() {
        let isFirstRun = !UserDefaults.standard.bool(forKey: "hasCompletedFirstTranscription")
        let timeout: TimeInterval = isFirstRun ? 180.0 : 5.0

        print("⏱️  HUDViewModel: Starting transcription timeout (\\(timeout)s)")

        transcriptionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Only show timeout error if still in transcribing state
            if case .transcribing = self.currentState {
                print("❌ HUDViewModel: Transcription timeout reached")
                self.currentState = .error(message: "Timeout", duration: 2.0)
                self.startErrorDismissTimer()

                // Reset AppState to idle
                Task { @MainActor in
                    AppState.shared.currentState = .idle
                }
            }
        }
    }

    /// Start error auto-dismiss timer (2 seconds)
    private func startErrorDismissTimer() {
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            print("🔄 HUDViewModel: Error auto-dismissing to waiting state")
            self.currentState = .waiting

            // Ensure AppState is also idle
            Task { @MainActor in
                if case .error = AppState.shared.currentState {
                    AppState.shared.currentState = .idle
                }
            }
        }
    }

    // MARK: - Error Message Mapping

    /// Map AppState errors to user-friendly HUD messages
    private func mapErrorMessage(_ error: Error) -> String {
        // Check for LLM-specific errors
        if let llmError = error as? LLMError {
            switch llmError {
            case .networkError:
                return "Network error"
            case .timeout:
                return "Timeout"
            case .invalidAPIKey:
                return "Invalid API key"
            case .rateLimited:
                return "Rate limited"
            case .invalidResponse, .emptyResponse:
                return "Service error"
            default:
                return "Service error"
            }
        }

        // Check for audio/microphone errors
        let errorDesc = error.localizedDescription.lowercased()
        if errorDesc.contains("mic") || errorDesc.contains("audio") || errorDesc.contains("microphone") {
            return "No mic access"
        }

        // Check for transcription errors
        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .notInitialized:
                return "Not initialized"
            case .modelNotFound:
                return "Model not found"
            case .invalidAudioFormat:
                return "Invalid audio"
            case .emptyResult:
                return "No speech detected"
            case .timeout:
                return "Timeout"
            case .failed:
                return "Processing failed"
            }
        }

        // Generic fallback
        return "Error occurred"
    }

    // MARK: - Cleanup
    deinit {
        errorDismissTimer?.invalidate()
        transcriptionTimeoutTimer?.invalidate()
        print("🗑️  HUDViewModel: Deallocated")
    }
}
