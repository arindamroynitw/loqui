//
//  FloaterTimer.swift
//  Loqui
//
//  Timer display component for floater (MM:SS format)
//

import SwiftUI

/// Timer display for floater showing elapsed recording time
/// Format: MM:SS (no tenths), updates every 1 second
struct FloaterTimer: View {
    // MARK: - Properties
    let startTime: Date
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // MARK: - Body
    var body: some View {
        Text(formattedTime)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }

    // MARK: - Formatted Time
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer Management
    private func startTimer() {
        // Update every 1 second (not 0.1s like old HUD)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview
#Preview {
    FloaterTimer(startTime: Date())
        .frame(width: 200, height: 100)
        .background(Color.black.opacity(0.1))
}
