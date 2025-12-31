//
//  AppDelegate.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app - no Dock icon, menu bar only
        NSApp.setActivationPolicy(.accessory)
        print("✅ AppDelegate: Set activation policy to .accessory (no Dock icon)")

        // Initialize app state
        appState = AppState.shared
        print("✅ AppDelegate: AppState initialized")

        // Start fn key monitoring
        appState?.startKeyMonitoring()

        // TODO Phase 3: Initialize models in background
        // Task {
        //     await appState?.initializeModels()
        // }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 AppDelegate: Application will terminate")
        appState?.cleanup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Never terminate when windows close (menu bar app)
        return false
    }
}
