//
//  MenuBarIconView.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI

/// Menu bar icon that changes based on app state
struct MenuBarIconView: View {
    let state: AppState.State

    var body: some View {
        Group {
            switch state {
            case .idle:
                // Gray microphone - idle state
                Image(systemName: "mic.fill")
                    .foregroundColor(.secondary)

            case .recording:
                // Red pulsing microphone - recording
                if #available(macOS 14.0, *) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse.byLayer, options: .repeating)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                }

            case .processing:
                // Blue spinning waveform - processing
                if #available(macOS 15.0, *) {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.blue)
                        .symbolEffect(.rotate, options: .repeating)
                } else {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.blue)
                }

            case .error:
                // Orange exclamation - error
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

#Preview("Idle") {
    MenuBarIconView(state: .idle)
}

#Preview("Recording") {
    MenuBarIconView(state: .recording(startTime: Date()))
}

#Preview("Processing") {
    MenuBarIconView(state: .processing)
}

#Preview("Error") {
    MenuBarIconView(state: .error(NSError(domain: "test", code: 0)))
}
