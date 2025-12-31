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
    @StateObject private var permissionManager = PermissionManager()
    @State private var showPermissionWizard = false

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

        // Permission wizard window
        Window("Loqui Setup", id: "permission-wizard") {
            PermissionWizardView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
