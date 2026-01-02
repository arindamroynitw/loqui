//
//  TranscribingView.swift
//  Loqui
//
//  Transcribing (processing) state view for HUD
//  Circle 36×36 with spinner + pulsing border
//

import SwiftUI

/// Transcribing state view - "Working on it, almost done"
struct TranscribingView: View {
    // MARK: - Animation State
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Spinner icon (18×18)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18))
                .foregroundColor(.hudBlue)
                .rotationEffect(.degrees(rotationAngle))
        }
        .frame(width: 36, height: 36)
        .background(
            Circle()
                .strokeBorder(Color.hudBlue.opacity(pulseOpacity), lineWidth: 1.5)
        )
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animation Management

    private func startAnimations() {
        // Spinner: Continuous rotation (1.0s per revolution)
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Border pulse: Opacity 0.3 → 1.0 (1.5s loop)
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 1.0
        }

        print("🎬 TranscribingView: Animations started")
    }
}

// MARK: - Preview

#Preview {
    TranscribingView()
        .frame(width: 100, height: 100)
        .background(Color.black.opacity(0.3))
}
