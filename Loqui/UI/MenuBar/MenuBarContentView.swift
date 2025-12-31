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
        print("ℹ️  Opening About...")

        let alert = NSAlert()
        alert.messageText = "Loqui"
        alert.informativeText = "Fast Speech-to-Text for macOS\n\nMade by Arindam Roy"
        alert.alertStyle = .informational

        // Add social links as buttons
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "X (Twitter)")
        alert.addButton(withTitle: "LinkedIn")

        let response = alert.runModal()

        // Handle button clicks
        if response == .alertSecondButtonReturn {
            // X (Twitter) button clicked
            if let url = URL(string: "https://x.com/crosschainyoda") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            // LinkedIn button clicked
            if let url = URL(string: "https://www.linkedin.com/in/arindamroynitw/") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(AppState.shared)
}
