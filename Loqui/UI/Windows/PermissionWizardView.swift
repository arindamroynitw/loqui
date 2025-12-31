//
//  PermissionWizardView.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI

/// First-launch permission wizard
struct PermissionWizardView: View {
    @StateObject private var permissionManager = PermissionManager()
    @State private var currentStep: PermissionStep = .microphone
    @Environment(\.dismiss) private var dismiss

    enum PermissionStep {
        case microphone
        case inputMonitoring
        case accessibility
        case complete
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Welcome to Loqui")
                .font(.title)
                .fontWeight(.semibold)

            Text("Loqui needs a few permissions to work properly")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.vertical, 10)

            // Permission steps
            switch currentStep {
            case .microphone:
                PermissionStepView(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Loqui needs microphone access to hear your speech",
                    status: permissionManager.microphoneGranted ? .granted : .pending
                ) {
                    Task {
                        let granted = await permissionManager.requestMicrophone()
                        if granted {
                            currentStep = .inputMonitoring
                        }
                    }
                }

            case .inputMonitoring:
                PermissionStepView(
                    icon: "keyboard",
                    title: "Input Monitoring",
                    description: "Loqui monitors the fn key to trigger transcription",
                    status: permissionManager.inputMonitoringGranted ? .granted : .pending
                ) {
                    permissionManager.requestInputMonitoring()
                    // Poll for permission
                    checkInputMonitoring()
                }

            case .accessibility:
                PermissionStepView(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Loqui needs accessibility permission to insert text into applications",
                    status: permissionManager.accessibilityGranted ? .granted : .pending
                ) {
                    permissionManager.requestAccessibility()
                    // Poll for permission
                    checkAccessibility()
                }

            case .complete:
                VStack(spacing: 15) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("All Set!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Loqui is ready to use. Press and hold the fn key to start transcribing.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 350)
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }

    private func checkInputMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            permissionManager.checkAllPermissions()
            if permissionManager.inputMonitoringGranted {
                timer.invalidate()
                currentStep = .accessibility
            }
        }
    }

    private func checkAccessibility() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            permissionManager.checkAllPermissions()
            if permissionManager.accessibilityGranted {
                timer.invalidate()
                currentStep = .complete
            }
        }
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    enum PermissionStatus {
        case pending
        case granted
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if status == .granted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .foregroundColor(.green)
                }

                Button("Continue") {
                    // Move to next step automatically
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Grant Access") {
                    action()
                }
                .buttonStyle(.borderedProminent)

                Text("You may need to approve this in System Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PermissionWizardView()
}
