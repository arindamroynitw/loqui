//
//  PermissionsView.swift
//  Loqui
//
//  Created by Arindam Roy on 09/01/26.
//

import SwiftUI

/// Simple view for managing system permissions
struct PermissionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manage Permissions")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            Text("Loqui requires these system permissions to function:")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    title: "Microphone",
                    description: "Capture audio for transcription",
                    action: openMicrophoneSettings
                )

                PermissionRow(
                    title: "Input Monitoring",
                    description: "Detect fn key presses",
                    action: openInputMonitoringSettings
                )

                PermissionRow(
                    title: "Accessibility",
                    description: "Insert transcribed text",
                    action: openAccessibilitySettings
                )
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 480, height: 320)
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Row for each permission with a button to open System Settings
struct PermissionRow: View {
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    PermissionsView()
}
