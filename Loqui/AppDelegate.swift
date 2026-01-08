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
        print("📍 INIT CHECKPOINT: AppDelegate.applicationDidFinishLaunching()")

        // Set as accessory app - no Dock icon, menu bar only
        NSApp.setActivationPolicy(.accessory)
        print("✅ AppDelegate: Set activation policy to .accessory (no Dock icon)")

        // Initialize app state
        appState = AppState.shared
        print("✅ AppDelegate: AppState initialized")

        // Start fn key monitoring (will request Input Monitoring if needed)
        print("📍 INIT CHECKPOINT: AppDelegate starting key monitoring")
        let result = appState?.startKeyMonitoring()

        switch result {
        case .success:
            print("✅ AppDelegate: fn key monitoring started successfully")
        case .failure(let error):
            print("⚠️ AppDelegate: fn key monitoring needs permission: \(error.localizedDescription)")
            // Permission will be requested when user presses fn for the first time
        case .none:
            print("⚠️ AppDelegate: appState is nil, cannot start monitoring")
        }

        // Initialize models in background
        print("📍 INIT CHECKPOINT: AppDelegate starting model initialization")
        Task {
            await appState?.initializeModels()
        }
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
