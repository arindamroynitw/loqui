//
//  TextInserter.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import AppKit
import Carbon

/// Inserts transcribed text into the active application
/// Uses clipboard + Cmd+V method for maximum compatibility
class TextInserter {

    /// Insert text into the currently focused application
    /// - Parameter text: The text to insert
    /// - Throws: TextInserterError if insertion fails
    func insertText(_ text: String) throws {
        print("📝 TextInserter: Inserting '\(text)'")

        // Check if we have Accessibility permission
        guard AXIsProcessTrusted() else {
            print("❌ TextInserter: Accessibility permission not granted")
            throw TextInserterError.accessibilityPermissionDenied
        }

        // Save current clipboard contents for restoration (optional - we skip this for simplicity)
        // let previousClipboard = NSPasteboard.general.string(forType: .string)

        // Set clipboard to our text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            print("❌ TextInserter: Failed to set clipboard")
            throw TextInserterError.clipboardFailed
        }

        print("✅ TextInserter: Clipboard set")

        // Small delay to ensure clipboard is ready
        Thread.sleep(forTimeInterval: 0.05)

        // Simulate Cmd+V
        do {
            try simulateCmdV()
            print("✅ TextInserter: Text inserted successfully")
        } catch {
            print("❌ TextInserter: Failed to simulate Cmd+V: \(error)")
            throw error
        }

        // Note: We don't restore the previous clipboard to keep it simple
        // The user's transcribed text stays on the clipboard for manual pasting if needed
    }

    /// Simulate Cmd+V keypress using CGEvent
    private func simulateCmdV() throws {
        // Virtual key code for 'V' is 0x09
        let vKeyCode: CGKeyCode = 0x09

        // Create key down event with Cmd modifier
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: true
        ) else {
            throw TextInserterError.eventCreationFailed
        }

        keyDownEvent.flags = .maskCommand

        // Create key up event with Cmd modifier
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: false
        ) else {
            throw TextInserterError.eventCreationFailed
        }

        keyUpEvent.flags = .maskCommand

        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)  // Small delay between down and up
        keyUpEvent.post(tap: .cghidEventTap)

        print("✅ TextInserter: Cmd+V simulated")
    }
}

/// Text insertion errors
enum TextInserterError: Error, LocalizedError {
    case accessibilityPermissionDenied
    case clipboardFailed
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to insert text. Please enable it in System Settings → Privacy & Security → Accessibility."
        case .clipboardFailed:
            return "Failed to copy text to clipboard"
        case .eventCreationFailed:
            return "Failed to create keyboard event"
        }
    }
}
