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
    @Environment(\.openSettings) private var openSettingsAction

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status indicator
            Text(appState.statusText)
                .font(.system(.body, design: .default))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Styled separator
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            // Settings button
            Button("Settings...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.vertical, 4)

            // About button
            Button("About Loqui") {
                openAbout()
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.vertical, 4)

            // Styled separator
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            // Quit button
            Button("Quit Loqui") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 250)
    }

    private func openSettings() {
        print("⚙️  Opening Settings...")

        // Activate the app to bring it to foreground (like About dialog)
        NSApp.activate(ignoringOtherApps: true)

        // Open settings window using environment action
        openSettingsAction()
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
