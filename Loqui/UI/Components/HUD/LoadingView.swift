//
//  LoadingView.swift
//  Loqui
//
//  Loading state view for HUD
//  Pill 200×44 with spinner + "Loading models..." text
//

import SwiftUI

/// Loading state view - "Models initializing, please wait"
struct LoadingView: View {
    // MARK: - Animation State
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // Spinner icon (18×18)
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 18, height: 18)

            // Loading text
            Text("Loading models...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.hudBlue, lineWidth: 2.0)
        )
    }
}

// MARK: - Preview

#Preview {
    LoadingView()
        .frame(width: 300, height: 100)
        .background(Color.black.opacity(0.3))
}
