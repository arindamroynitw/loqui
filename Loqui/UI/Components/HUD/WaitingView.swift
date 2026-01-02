//
//  WaitingView.swift
//  Loqui
//
//  Waiting (idle) state view for HUD
//  Circle 36×36 with Flow logo, subtle border
//

import SwiftUI

/// Waiting state view - ambient presence, "I'm ready"
struct WaitingView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Flow logo icon (16×16)
            // TODO: Replace with actual logo-flow-simplified asset when added
            Image(systemName: "waveform.circle")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .frame(width: 36, height: 36)
        .background(
            Circle()
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .opacity(0.8)
    }

    /// Border color with dark mode adaptation
    private var borderColor: Color {
        let opacity = colorScheme == .dark ? 0.5 : 0.3
        return Color.hudBlue.opacity(opacity)
    }
}

// MARK: - Preview

#Preview {
    WaitingView()
        .frame(width: 100, height: 100)
        .background(Color.black.opacity(0.3))
}
