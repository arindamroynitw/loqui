//
//  LoquiApp.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI

@main
struct LoquiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Menu bar icon with dropdown
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
        } label: {
            MenuBarIconView(state: appState.currentState)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
        }

        // About window
        Window("About Loqui", id: "about-window") {
            AboutWindow()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 480)

        // Permissions window
        Window("Manage Permissions", id: "permissions-window") {
            PermissionsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 320)
    }
}
