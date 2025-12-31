//
//  HUDWindowController.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import AppKit
import SwiftUI

/// Controls the floating HUD window that appears during recording
@MainActor
class HUDWindowController {
    private var window: NSWindow?
    private let startTime: Date

    init(startTime: Date) {
        self.startTime = startTime
    }

    /// Show the HUD window
    func show() {
        // Create HUD content
        let contentView = HUDContentView(startTime: startTime)

        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 180, height: 50)

        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating  // Float above other windows
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = true  // Don't intercept clicks
        window.hasShadow = false  // Content view has its own shadow

        // Position at center-bottom of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - (windowFrame.width / 2)
            let y = screenFrame.minY + 100  // 100pt from bottom
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Fade in animation
        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 1.0
        })

        self.window = window
        print("✅ HUD: Window shown")
    }

    /// Hide the HUD window
    func hide() {
        guard let window = window else { return }

        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            self.window = nil
            print("✅ HUD: Window hidden")
        })
    }
}
