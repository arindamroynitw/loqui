//
//  HUDWindowController.swift
//  Loqui
//
//  Window controller for HUD with morphing animations and click handling
//  Based on HUD_design_spec.md
//

import AppKit
import SwiftUI
import Combine

/// HUD window controller with morphing pill animations
@MainActor
class HUDWindowController {
    // MARK: - Properties
    private var window: NSWindow?
    private var hostingView: NSHostingView<HUDContentView>?
    private var viewModel = HUDViewModel()
    private var cancellables = Set<AnyCancellable>()

    // Window positioning
    private let margin: CGFloat = 20  // Distance from screen edges

    // MARK: - Initialization

    init() {
        print("✨ HUDWindowController: Initializing...")
        setupWindow()
        setupClickGesture()
        setupStateObserver()
        print("✅ HUDWindowController: Initialized")
    }

    // MARK: - Window Setup

    private func setupWindow() {
        // Create SwiftUI content view
        let contentView = HUDContentView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 36, height: 36)
        self.hostingView = hostingView

        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false  // CHANGED from floater (was true)
        window.level = .statusBar  // CHANGED from floater (was .floating)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = false  // CRITICAL: Must receive clicks

        self.window = window

        // Position at top-right
        positionAtTopRight()

        print("✅ HUDWindowController: Window created")
    }

    // MARK: - Positioning

    /// Position window at top-right corner of main screen
    private func positionAtTopRight() {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = screenFrame.maxX - windowFrame.width - margin
        let y = screenFrame.maxY - windowFrame.height - margin

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - State Observation

    private func setupStateObserver() {
        viewModel.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)

        print("✅ HUDWindowController: State observer configured")
    }

    private func handleStateChange(_ newState: HUDState) {
        print("🔄 HUDWindowController: State changed to \\(newState)")

        // Morph to new size
        morphTo(size: newState.size)
    }

    // MARK: - Morphing Animation

    /// Morph window to new size with 200ms animation
    /// CRITICAL: Keeps top-right corner fixed during resize
    private func morphTo(size: CGSize, duration: TimeInterval = 0.2) {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame

        // Calculate new origin to keep TOP-RIGHT corner fixed
        let newX = screenFrame.maxX - size.width - margin
        let newY = screenFrame.maxY - size.height - margin
        let newOrigin = NSPoint(x: newX, y: newY)
        let newFrame = NSRect(origin: newOrigin, size: size)

        // Animate window frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        })

        // Update hosting view frame
        hostingView?.frame = NSRect(origin: .zero, size: size)

        print("📏 HUDWindowController: Morphed to \\(size.width)×\\(size.height)")
    }

    // MARK: - Click Handling

    private func setupClickGesture() {
        guard let hostingView = hostingView else { return }

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        clickGesture.numberOfClicksRequired = 1
        hostingView.addGestureRecognizer(clickGesture)

        print("✅ HUDWindowController: Click gesture configured")
    }

    @MainActor
    @objc private func handleClick() {
        let appState = AppState.shared

        print("👆 HUDWindowController: Click detected in state \\(viewModel.currentState)")

        switch viewModel.currentState {
        case .loading:
            // Ignore clicks during model loading
            print("⚠️  HUDWindowController: Click ignored during model loading")

        case .waiting:
            // Check for API keys
            if !appState.hasAPIKeys {
                showNoAPIKeysAlert()
                return
            }

            // Start recording (equivalent to fn key press)
            appState.startRecording()

        case .recording:
            // Stop recording (equivalent to fn key release)
            // Power user mode: click toggles start/stop
            appState.stopRecording()

        case .transcribing:
            // Ignore clicks during processing (spec: click does nothing)
            print("⚠️  HUDWindowController: Click ignored during transcribing")

        case .error:
            // Allow retry - error auto-recovers to idle
            break
        }
    }

    private func showNoAPIKeysAlert() {
        print("⚠️  HUDWindowController: Showing no API keys alert")

        let alert = NSAlert()
        alert.messageText = "No API Keys Configured"
        alert.informativeText = "Please configure your Groq or OpenAI API key in Settings (Cmd+,) to use Loqui."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Public API

    /// Show HUD window
    func show() {
        window?.orderFront(nil)
        print("✅ HUD: Window shown")
    }

    /// Hide HUD window
    func hide() {
        window?.orderOut(nil)
        print("✅ HUD: Window hidden")
    }

    /// Manually set HUD to loading state (called during model initialization)
    func setLoadingState() {
        viewModel.currentState = .loading
        print("✅ HUD: Manually set to loading state")
    }

    /// Manually set HUD to waiting state (called after model initialization)
    func setWaitingState() {
        viewModel.currentState = .waiting
        print("✅ HUD: Manually set to waiting state")
    }

    // MARK: - Cleanup

    deinit {
        print("🗑️  HUDWindowController: Deallocated")
    }
}
