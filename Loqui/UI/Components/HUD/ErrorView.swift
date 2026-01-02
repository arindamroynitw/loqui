//
//  ErrorView.swift
//  Loqui
//
//  Error state view for HUD
//  Pill 180×44 (dynamic width) with error icon + text
//

import SwiftUI

/// Error state view - "Oops, something went wrong"
struct ErrorView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            // Error icon (20×20)
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.hudRed)

            // Error text (IBM Plex Sans Medium 13px, fallback to SF Pro)
            Text(message)
                .font(ibmPlexSansFont)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.hudRed, lineWidth: 2.0)
        )
    }

    // MARK: - Font Selection

    /// IBM Plex Sans Medium 13px (fallback to SF Pro Text Medium)
    private var ibmPlexSansFont: Font {
        if let _ = NSFont(name: "IBMPlexSans-Medium", size: 13) {
            return Font.custom("IBMPlexSans-Medium", size: 13)
        } else {
            return Font.system(size: 13, weight: .medium)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ErrorView(message: "Network error")
        ErrorView(message: "No mic access")
        ErrorView(message: "Timeout")
        ErrorView(message: "Service error")
    }
    .frame(width: 300, height: 300)
    .background(Color.black.opacity(0.3))
}
