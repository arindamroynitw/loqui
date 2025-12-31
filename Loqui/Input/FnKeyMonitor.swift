//
//  FnKeyMonitor.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Cocoa
import CoreGraphics

/// Monitors the fn key globally using CGEventTap
class FnKeyMonitor {
    private var eventTap: CFMachPort?
    fileprivate var previousFnState = false  // fileprivate so callback can access it

    /// Start monitoring the fn key
    /// Requires Input Monitoring permission
    func start() {
        // Check if we have Input Monitoring permission
        guard CGPreflightListenEventAccess() else {
            print("⚠️ FnKeyMonitor: Input Monitoring permission not granted. Requesting...")
            CGRequestListenEventAccess()
            return
        }

        print("✅ FnKeyMonitor: Input Monitoring permission granted")

        // Create event mask for flagsChanged events (modifier key changes)
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        // Create the event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Non-intrusive, works with sandboxed apps
            eventsOfInterest: eventMask,
            callback: fnKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ FnKeyMonitor: Failed to create event tap")
            return
        }

        self.eventTap = tap

        // Add to run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ FnKeyMonitor: Started monitoring fn key")
    }

    /// Stop monitoring the fn key
    func stop() {
        guard let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        eventTap = nil

        print("🛑 FnKeyMonitor: Stopped monitoring fn key")
    }

    deinit {
        stop()
    }
}

// MARK: - Event Callback

/// CGEventTap callback function for detecting fn key state changes
private let fnKeyCallback: CGEventTapCallBack = { (proxy, type, event, userInfo) in
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    // Retrieve the FnKeyMonitor instance
    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    // Check if fn key is pressed via CGEventFlags.maskSecondaryFn (bit 23, value 0x800000)
    let fnPressed = event.flags.contains(.maskSecondaryFn)

    // Detect state change (pressed or released)
    if fnPressed != monitor.previousFnState {
        if fnPressed {
            // fn key was just pressed
            print("🎤 FnKeyMonitor: fn key PRESSED")
            NotificationCenter.default.post(name: .fnKeyPressed, object: nil)
        } else {
            // fn key was just released
            print("🎤 FnKeyMonitor: fn key RELEASED")
            NotificationCenter.default.post(name: .fnKeyReleased, object: nil)
        }

        monitor.previousFnState = fnPressed
    }

    // Pass the event through (listen-only mode)
    return Unmanaged.passUnretained(event)
}
