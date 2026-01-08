//
//  PermissionManager.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import AVFoundation
import ApplicationServices
import AppKit

/// Permission-related errors
enum PermissionError: Error, LocalizedError {
    case microphoneDenied
    case inputMonitoringDenied
    case accessibilityDenied
    case audioEngineSetupFailed

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone permission denied. Please enable microphone access in System Settings."
        case .inputMonitoringDenied:
            return "Input Monitoring permission denied. Please enable Input Monitoring in System Settings."
        case .accessibilityDenied:
            return "Accessibility permission denied. Please enable Accessibility access in System Settings."
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine for microphone request."
        }
    }
}

/// Manages all required permissions for Loqui
@MainActor
class PermissionManager: ObservableObject {
    @Published var microphoneGranted = false
    @Published var inputMonitoringGranted = false
    @Published var accessibilityGranted = false

    /// Check all permissions and update published properties
    func checkAllPermissions() {
        // Check microphone using AVAudioEngine (matches what Settings grants)
        // This may trigger a prompt if permission not yet granted, but that's expected behavior
        microphoneGranted = checkMicrophonePermission()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()

        print("📋 Permission Status:")
        print("   Microphone: \(microphoneGranted ? "✅" : "❌")")
        print("   Input Monitoring: \(inputMonitoringGranted ? "✅" : "❌")")
        print("   Accessibility: \(accessibilityGranted ? "✅" : "❌")")
    }

    /// Check microphone permission using AVAudioEngine
    /// Returns true if permission granted, false otherwise
    /// Note: This checks the actual permission that Settings grants (not AVCaptureDevice)
    private func checkMicrophonePermission() -> Bool {
        // First try the non-intrusive check
        let captureStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if captureStatus == .authorized {
            return true
        }

        // If AVCaptureDevice says not authorized, do a real check with AVAudioEngine
        // This is the actual API we use for recording, so it's the authoritative check
        // It will NOT trigger a prompt if permission already granted via Settings
        do {
            let audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)

            // If we can get a valid format without error, permission is granted
            let granted = inputFormat.sampleRate > 0
            print("🎤 Microphone check (AVAudioEngine): \(granted ? "✅" : "❌")")
            return granted
        } catch {
            print("🎤 Microphone check (AVAudioEngine): ❌ Error: \(error.localizedDescription)")
            return false
        }
    }

    /// Request microphone permission via AVAudioEngine
    /// Uses the same API as WhisperAudioCapture to avoid duplicate prompts
    /// - Throws: PermissionError if denied or setup fails
    func requestMicrophoneViaAudioEngine() async throws {
        print("🎤 Requesting microphone via AVAudioEngine...")

        // Create a temporary audio engine to trigger microphone permission
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            print("❌ Failed to get valid input format")
            throw PermissionError.audioEngineSetupFailed
        }

        // Install tap to trigger permission prompt
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { _, _ in
            // No-op - just need to trigger permission
        }

        do {
            try audioEngine.start()
            print("✅ Audio engine started - microphone access granted")

            // Cleanup
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)

            await MainActor.run {
                self.microphoneGranted = true
            }
        } catch {
            print("❌ Audio engine failed to start: \(error.localizedDescription)")
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)

            await MainActor.run {
                self.microphoneGranted = false
            }

            throw PermissionError.microphoneDenied
        }
    }

    /// Request Input Monitoring permission
    /// This opens System Settings but doesn't provide a callback
    /// Must poll to detect when permission is granted
    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        print("⌨️  Input Monitoring: Opening System Settings...")

        // Poll for permission grant (no callback available)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                if CGPreflightListenEventAccess() {
                    self?.inputMonitoringGranted = true
                    print("⌨️  Input Monitoring: ✅ Granted")
                    timer.invalidate()
                }
            }
        }
    }

    /// Request Accessibility permission
    /// This opens System Settings with a prompt
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)

        if granted {
            self.accessibilityGranted = true
            print("♿️ Accessibility: ✅ Already granted")
        } else {
            print("♿️ Accessibility: Opening System Settings...")

            // Poll for permission grant (no callback available)
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    if AXIsProcessTrusted() {
                        self?.accessibilityGranted = true
                        print("♿️ Accessibility: ✅ Granted")
                        timer.invalidate()
                    }
                }
            }
        }
    }

    /// Open System Settings to a specific privacy panel
    /// - Parameter panel: Privacy panel name (e.g., "Microphone", "ListenEvent", "Accessibility")
    func openSystemSettings(for panel: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_\(panel)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            print("⚙️  Opening System Settings: \(panel)")
        }
    }

    /// Check if all required permissions are granted
    var allPermissionsGranted: Bool {
        microphoneGranted && inputMonitoringGranted && accessibilityGranted
    }

    // MARK: - Alert Helpers

    /// Show alert when permission is denied
    /// - Parameter permissionType: Type of permission that was denied
    func showPermissionDeniedAlert(for permissionType: String) {
        let alert = NSAlert()
        alert.messageText = "\(permissionType) Permission Required"
        alert.informativeText = "Loqui needs \(permissionType) permission to function. Please enable it in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings
            let panel = permissionType == "Microphone" ? "Microphone" :
                        permissionType == "Input Monitoring" ? "ListenEvent" :
                        permissionType == "Accessibility" ? "Accessibility" : ""

            if !panel.isEmpty {
                openSystemSettings(for: panel)
            }
        }
    }
}
