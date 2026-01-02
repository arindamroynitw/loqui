//
//  RecordingView.swift
//  Loqui
//
//  Recording state view for HUD
//  Pill 140×44 with waveform animation + timer dots
//

import SwiftUI

/// Recording state view - active listening with waveform + dots
struct RecordingView: View {
    let startTime: Date

    // MARK: - Waveform State
    @State private var barHeights: [CGFloat] = [12, 16, 20, 14, 10]
    @State private var waveformTimer: Timer?

    // MARK: - Timer Dots State
    @State private var activeDotIndex: Int = 0
    @State private var dotsTimer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            // Waveform animation (left, 100px wide)
            waveformView
                .frame(width: 100)

            // Timer dots (right, 40px wide)
            timerDotsView
                .frame(width: 40)
        }
        .frame(width: 140, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.hudBlue, lineWidth: 2.0)
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }

    // MARK: - Waveform View

    private var waveformView: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(Color.hudBlue)
                    .frame(width: 3, height: barHeights[index])
                    .animation(.easeInOut(duration: 0.3), value: barHeights[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Timer Dots View

    private var timerDotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.hudBlue)
                    .frame(width: 4, height: 4)
                    .opacity(activeDotIndex == index ? 1.0 : 0.3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Animation Management

    private func startAnimations() {
        // Waveform: Update bar heights every 300ms
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            barHeights = (0..<5).map { _ in CGFloat.random(in: 8...24) }
        }

        // Timer dots: Cycle every 1.2s (0.4s per dot)
        dotsTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            activeDotIndex = (activeDotIndex + 1) % 3
        }

        print("🎬 RecordingView: Animations started")
    }

    private func stopAnimations() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        dotsTimer?.invalidate()
        dotsTimer = nil

        print("🛑 RecordingView: Animations stopped")
    }
}

// MARK: - Preview

#Preview {
    RecordingView(startTime: Date())
        .frame(width: 200, height: 100)
        .background(Color.black.opacity(0.3))
}
