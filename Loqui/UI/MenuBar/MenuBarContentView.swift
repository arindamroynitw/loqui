//
//  MenuBarContentView.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI

/// Content view for the menu bar dropdown
struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status indicator
            Text(appState.statusText)
                .font(.system(.body, design: .default))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Model info
            Text("Model: \(appState.currentModel)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            // Settings link
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)

            // About button
            Button("About Loqui") {
                openAbout()
            }

            Divider()

            // Quit button
            Button("Quit Loqui") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 250)
    }

    private func openAbout() {
        // TODO Phase 5: Open About window
        print("ℹ️  Opening About... (TODO)")

        // For now, show a simple alert
        let alert = NSAlert()
        alert.messageText = "Loqui"
        alert.informativeText = "Personal Fast Speech-to-Text for macOS\n\nVersion 1.0 (Phase 1 Development)\n\n🔒 All processing happens on-device."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(AppState.shared)
}
