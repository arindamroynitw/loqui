//
//  MenuBarIconView.swift
//  Loqui
//
//  Menu bar icon with Flow logo and state-based effects
//

import SwiftUI

/// Menu bar icon that changes color and animation based on app state
struct MenuBarIconView: View {
    let state: AppState.State

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)  // 18pt for better visibility in menu bar
            .foregroundColor(colorForState)
            .modifier(EffectModifier(state: state))
    }

    /// Color based on current state
    private var colorForState: Color {
        switch state {
        case .idle:
            return .secondary  // Gray - ready
        case .recording:
            return .red  // Red - recording
        case .processing:
            return .blue  // Blue - transcribing
        case .error:
            return .orange  // Orange - error
        }
    }
}

/// Animation effects for different states
struct EffectModifier: ViewModifier {
    let state: AppState.State
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0

    func body(content: Content) -> some View {
        switch state {
        case .recording:
            // Pulse effect for recording
            if #available(macOS 14.0, *) {
                content
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            } else {
                // Fallback: manual pulse animation
                content
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .opacity(isPulsing ? 0.8 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }

        case .processing:
            // Rotation effect for processing
            if #available(macOS 15.0, *) {
                content
                    .symbolEffect(.rotate, options: .repeating)
            } else {
                // Fallback: manual rotation animation
                content
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }

        default:
            // No animation for idle and error states
            content
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    MenuBarIconView(state: .idle)
        .padding()
        .background(Color.black.opacity(0.2))
}

#Preview("Recording") {
    MenuBarIconView(state: .recording(startTime: Date()))
        .padding()
        .background(Color.black.opacity(0.2))
}

#Preview("Processing") {
    MenuBarIconView(state: .processing)
        .padding()
        .background(Color.black.opacity(0.2))
}

#Preview("Error") {
    MenuBarIconView(state: .error(NSError(domain: "test", code: 0)))
        .padding()
        .background(Color.black.opacity(0.2))
}
