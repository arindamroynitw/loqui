//
//  PermissionManager.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import AVFoundation
import ApplicationServices
import AppKit

/// Manages all required permissions for Loqui
@MainActor
class PermissionManager: ObservableObject {
    @Published var microphoneGranted = false
    @Published var inputMonitoringGranted = false
    @Published var accessibilityGranted = false

    /// Check all permissions and update published properties
    func checkAllPermissions() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()

        print("📋 Permission Status:")
        print("   Microphone: \(microphoneGranted ? "✅" : "❌")")
        print("   Input Monitoring: \(inputMonitoringGranted ? "✅" : "❌")")
        print("   Accessibility: \(accessibilityGranted ? "✅" : "❌")")
    }

    /// Request microphone permission
    /// - Returns: True if granted, false if denied
    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            self.microphoneGranted = granted
        }
        print("🎤 Microphone permission: \(granted ? "✅ Granted" : "❌ Denied")")
        return granted
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
}
