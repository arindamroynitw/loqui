//
//  FloaterWindowController.swift
//  Loqui
//
//  Persistent Siri-style animated floater for recording status
//

import SwiftUI
import AppKit
import Combine

/// Observable state for the floater content view
@MainActor
class FloaterState: ObservableObject {
    @Published var color: Color = .floaterBlue
    @Published var glowMode: FloaterContentView.GlowMode = .staticPulse
    @Published var showTimer: Bool = false
    @Published var timerStartTime: Date?
}

/// Persistent floater window controller for always-visible recording status
/// Positioned at top-right corner with state-based colors and animations
@MainActor
class FloaterWindowController {
    // MARK: - Properties
    private var window: NSWindow?
    private var hostingView: NSHostingView<FloaterContentView>?
    private var floaterState = FloaterState()
    private var cancellables = Set<AnyCancellable>()

    // Size constants (from spec)
    private let compactSize: CGFloat = 28  // Idle state
    private let expandedSize: CGFloat = 44  // Recording/Processing state

    // Current state tracking
    private var currentSize: CGFloat = 28
    private var currentState: AppState.State = .idle

    // MARK: - Initialization
    init() {
        print("✨ FloaterWindowController: Initializing...")
        setupWindow()
        setupClickGesture()
        setupStateObserver()
        print("✅ FloaterWindowController: Initialized")
    }

    // MARK: - Window Setup
    private func setupWindow() {
        // Create content view with observable state
        let contentView = FloaterContentView(state: floaterState)

        // Create hosting view (start with compact size)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: compactSize, height: compactSize)
        self.hostingView = hostingView

        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: compactSize, height: compactSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating  // Above normal windows
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false  // CRITICAL: Must receive clicks
        window.hasShadow = true  // For glow effect

        // Position at top-right
        positionAtTopRight()

        self.window = window
        print("✅ FloaterWindowController: Window created and positioned")
    }

    // MARK: - Positioning
    private func positionAtTopRight() {
        guard let window = window, let screen = NSScreen.main else { return }

        let margin: CGFloat = 25  // 20-30pt as specified
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = screenFrame.maxX - windowFrame.width - margin
        let y = screenFrame.maxY - windowFrame.height - margin

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - State Observation
    private func setupStateObserver() {
        AppState.shared.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.updateAppearance(for: newState)
            }
            .store(in: &cancellables)

        print("✅ FloaterWindowController: State observer configured")
    }

    private func updateAppearance(for state: AppState.State) {
        currentState = state

        switch state {
        case .idle:
            animateToCompact()
            floaterState.color = .floaterBlue
            floaterState.glowMode = .staticPulse
            floaterState.showTimer = false
            floaterState.timerStartTime = nil

        case .recording(let startTime):
            animateToExpanded()
            floaterState.color = .floaterGreen
            floaterState.glowMode = .activePulse
            floaterState.showTimer = true
            floaterState.timerStartTime = startTime

        case .processing:
            // Keep expanded, change color, hide timer IMMEDIATELY
            floaterState.showTimer = false
            floaterState.timerStartTime = nil
            floaterState.color = .floaterAmber
            floaterState.glowMode = .activePulse

        case .error:
            // Flash red, shake, then return to idle appearance
            animateError()
        }
    }

    // MARK: - Size Animations
    private func animateToExpanded() {
        guard currentSize != expandedSize else { return }
        currentSize = expandedSize

        print("📏 FloaterWindowController: Expanding to \(expandedSize)pt")

        // Calculate new position BEFORE animating (to avoid jump)
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 25
        let screenFrame = screen.visibleFrame
        let newX = screenFrame.maxX - expandedSize - margin
        let newY = screenFrame.maxY - expandedSize - margin
        let newOrigin = NSPoint(x: newX, y: newY)

        // Animate size AND position together
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            window?.animator().setFrame(NSRect(origin: newOrigin, size: NSSize(width: expandedSize, height: expandedSize)), display: true)
            hostingView?.animator().frame = NSRect(x: 0, y: 0, width: expandedSize, height: expandedSize)
        })
    }

    private func animateToCompact() {
        guard currentSize != compactSize else { return }
        currentSize = compactSize

        print("📏 FloaterWindowController: Contracting to \(compactSize)pt")

        // Calculate new position BEFORE animating (to avoid jump)
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 25
        let screenFrame = screen.visibleFrame
        let newX = screenFrame.maxX - compactSize - margin
        let newY = screenFrame.maxY - compactSize - margin
        let newOrigin = NSPoint(x: newX, y: newY)

        // Animate size AND position together
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            window?.animator().setFrame(NSRect(origin: newOrigin, size: NSSize(width: compactSize, height: compactSize)), display: true)
            hostingView?.animator().frame = NSRect(x: 0, y: 0, width: compactSize, height: compactSize)
        })
    }

    private func animateShake() {
        // Brief shake animation (processing state click feedback)
        guard let window = window else { return }

        print("🔔 FloaterWindowController: Shake animation")

        let originalOrigin = window.frame.origin
        let shakeDistance: CGFloat = 8

        // Shake sequence: right → left → center (0.3s total)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true

            window.setFrameOrigin(NSPoint(x: originalOrigin.x + shakeDistance, y: originalOrigin.y))
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                window.setFrameOrigin(NSPoint(x: originalOrigin.x - shakeDistance, y: originalOrigin.y))
            }, completionHandler: {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.1
                    window.setFrameOrigin(originalOrigin)
                })
            })
        })
    }

    private func animateError() {
        // Flash red, shake, return to idle appearance after 1.5s
        print("❌ FloaterWindowController: Error animation")

        floaterState.color = .floaterRed
        animateShake()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.floaterState.color = .floaterBlue
            self.animateToCompact()
            self.floaterState.glowMode = .staticPulse
        }
    }

    // MARK: - Click Handling
    private func setupClickGesture() {
        guard let hostingView = hostingView else { return }

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        clickGesture.numberOfClicksRequired = 1
        hostingView.addGestureRecognizer(clickGesture)

        print("✅ FloaterWindowController: Click gesture configured")
    }

    @MainActor
    @objc private func handleClick() {
        let appState = AppState.shared

        print("👆 FloaterWindowController: Click detected in state \(appState.currentState)")

        switch appState.currentState {
        case .idle:
            // Check for API keys
            if !appState.hasAPIKeys {
                showNoAPIKeysAlert()
                return
            }

            // Start recording (equivalent to fn key press)
            appState.startRecording()

        case .recording:
            // Stop recording (equivalent to fn key release)
            appState.stopRecording()

        case .processing:
            // Show shake animation, do nothing
            animateShake()

        case .error:
            // Allow retry, AppState already auto-recovers to idle after 2s
            break
        }
    }

    private func showNoAPIKeysAlert() {
        print("⚠️  FloaterWindowController: Showing no API keys alert")

        let alert = NSAlert()
        alert.messageText = "No API Keys Configured"
        alert.informativeText = "Please configure your Groq or OpenAI API key in Settings (Cmd+,) to use Loqui."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Public API
    func show() {
        window?.orderFront(nil)
        print("✅ Floater: Window shown")
    }

    func hide() {
        window?.orderOut(nil)
        print("✅ Floater: Window hidden")
    }

    func setDisabled() {
        // Gray disabled state when no API keys
        print("⚙️  Floater: Setting disabled (gray) state")
        floaterState.color = .floaterGray
        floaterState.glowMode = .none
    }

    deinit {
        print("🗑️  FloaterWindowController: Deallocated")
    }
}
