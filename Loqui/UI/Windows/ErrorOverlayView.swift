//
//  ErrorOverlayView.swift
//  Loqui
//
//  Minimal error notification for LLM cleanup failures
//

import SwiftUI
import AppKit

/// Minimal error overlay for cleanup failures (liquid glass design)
struct ErrorOverlayView: View {
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)

            Text("Cleanup failed")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            VisualEffectView(
                material: .popover,
                blendingMode: .behindWindow,
                state: .active
            )
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            // Fade in
            withAnimation(.easeIn(duration: 0.2)) {
                isVisible = true
            }

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
            }
        }
    }
}

/// Controller for error overlay window (matches HUDWindowController pattern)
@MainActor
class ErrorOverlayController {
    private var window: NSWindow?

    func show() {
        // Create error overlay content
        let contentView = ErrorOverlayView()

        // Create hosting view (smaller size for compact design)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 32)

        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 32),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window (same as HUD)
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = true
        window.hasShadow = false

        // Position at center-bottom (slightly above HUD position)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - (windowFrame.width / 2)
            let y = screenFrame.minY + 160  // 160pt from bottom (HUD is at 100pt)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show immediately (no fade - handled by SwiftUI)
        window.orderFront(nil)
        self.window = window

        print("⚠️  ErrorOverlay: Shown")

        // Auto-hide after 3.4 seconds (3s display + 0.4s fade animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            self.hide()
        }
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        print("⚠️  ErrorOverlay: Hidden")
    }
}

#Preview {
    ErrorOverlayView()
        .frame(width: 300, height: 200)
}
