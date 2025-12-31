//
//  FloaterContentView.swift
//  Loqui
//
//  SwiftUI content view for the persistent floater
//  Features: Circular waveform icon, state-based colors, glowing effects
//

import SwiftUI

/// SwiftUI content view for the floater
/// Displays circular waveform icon with state-based colors and glow effects
struct FloaterContentView: View {
    // MARK: - Observable State
    @ObservedObject var state: FloaterState

    // MARK: - Local State (for animations)
    @State private var glowRadius: CGFloat = 4

    // MARK: - Glow Mode Enum
    enum GlowMode {
        case staticPulse  // Idle: gentle pulse
        case activePulse  // Recording/Processing: active pulse
        case none         // Gray disabled
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background circle with glow (no stroke outline)
            Circle()
                .fill(state.color)
                .shadow(color: glowColor, radius: glowRadius, x: 0, y: 0)

            // Waveform icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)

            // Timer overlay (only during recording)
            if state.showTimer, let startTime = state.timerStartTime {
                FloaterTimer(startTime: startTime)
                    .offset(y: 30)  // Below floater
            }
        }
        .frame(width: size, height: size)
        .onChange(of: state.glowMode) { _, newMode in
            startGlowAnimation(for: newMode)
        }
        .onAppear {
            startGlowAnimation(for: state.glowMode)
        }
    }

    // MARK: - Dynamic Properties
    private var size: CGFloat {
        state.showTimer ? 44 : 28
    }

    private var iconSize: CGFloat {
        state.showTimer ? 28 : 18
    }

    private var glowColor: Color {
        switch state.glowMode {
        case .staticPulse:
            return state.color.opacity(0.3)
        case .activePulse:
            return state.color.opacity(0.6)
        case .none:
            return .clear
        }
    }

    // MARK: - Glow Animation
    private func startGlowAnimation(for mode: GlowMode) {
        guard mode != .none else {
            glowRadius = 0
            return
        }

        // More subtle glow ranges to prevent visible oscillation
        let minRadius: CGFloat = mode == .staticPulse ? 3 : 6
        let maxRadius: CGFloat = mode == .staticPulse ? 5 : 10
        let duration: Double = mode == .staticPulse ? 2.0 : 1.5

        // Reset to min first
        glowRadius = minRadius

        // Then animate to max with smooth easing
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            glowRadius = maxRadius
        }
    }
}

// MARK: - Color Extensions (Muted Glowing Pastels)
extension Color {
    static let floaterBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let floaterGreen = Color(red: 0.4, green: 0.9, blue: 0.6)
    static let floaterAmber = Color(red: 1.0, green: 0.7, blue: 0.3)
    static let floaterRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let floaterGray = Color(white: 0.5)
}

// MARK: - Preview
#Preview {
    @StateObject var previewState = FloaterState()
    return FloaterContentView(state: previewState)
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.1))
}
