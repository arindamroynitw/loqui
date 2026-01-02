//
//  HUDState.swift
//  Loqui
//
//  State machine for HUD with computed properties for visual attributes
//  Based on HUD_design_spec.md
//

import Foundation
import SwiftUI
import AppKit

/// HUD state enum with associated values and computed visual properties
enum HUDState: Equatable {
    case loading  // Models initializing, user must wait
    case waiting
    case recording(startTime: Date)
    case transcribing
    case error(message: String, duration: TimeInterval)

    // MARK: - Computed Properties

    /// Window size for this state
    var size: CGSize {
        switch self {
        case .loading:
            return CGSize(width: 200, height: 44)  // Pill to show "Loading models..."
        case .waiting:
            return CGSize(width: 36, height: 36)
        case .recording:
            return CGSize(width: 140, height: 44)
        case .transcribing:
            return CGSize(width: 36, height: 36)
        case .error(let message, _):
            // Dynamic width based on text measurement
            let textWidth = measureErrorText(message)
            let iconWidth: CGFloat = 20
            let spacing: CGFloat = 8
            let padding: CGFloat = 24  // 12pt on each side
            let totalWidth = iconWidth + spacing + textWidth + padding
            return CGSize(width: max(180, totalWidth), height: 44)
        }
    }

    /// Corner radius for this state
    var cornerRadius: CGFloat {
        switch self {
        case .loading:
            return 22  // Pill corner radius
        case .waiting, .transcribing:
            return 18  // Circle (36 / 2)
        case .recording, .error:
            return 22  // Pill corner radius
        }
    }

    /// Border width for this state
    var borderWidth: CGFloat {
        switch self {
        case .loading:
            return 2.0
        case .waiting, .transcribing:
            return 1.5
        case .recording, .error:
            return 2.0
        }
    }

    /// Border color for this state
    var borderColor: Color {
        switch self {
        case .loading, .waiting, .recording, .transcribing:
            return .hudBlue
        case .error:
            return .hudRed
        }
    }

    // MARK: - Helper Methods

    /// Measure text width for error messages
    /// Uses IBM Plex Sans Medium 13px (fallback to SF Pro Text Medium)
    private func measureErrorText(_ message: String) -> CGFloat {
        let font = NSFont(name: "IBMPlexSans-Medium", size: 13) ??
                   NSFont.systemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (message as NSString).size(withAttributes: attributes)
        return size.width
    }
}
