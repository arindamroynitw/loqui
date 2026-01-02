//
//  HUDContentView.swift
//  Loqui
//
//  SwiftUI container for HUD with state-based view routing
//  Uses HUDViewModel for state management
//

import SwiftUI

/// Main HUD content view with state-driven layout
struct HUDContentView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        ZStack {
            // State-specific content
            stateView
                .transition(.opacity)
        }
        .frame(width: viewModel.currentState.size.width,
               height: viewModel.currentState.size.height)
        .background(blurBackground)
        .animation(.easeOut(duration: 0.2), value: viewModel.currentState)
    }

    // MARK: - State View Routing

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.currentState {
        case .loading:
            LoadingView()

        case .waiting:
            WaitingView()

        case .recording(let startTime):
            RecordingView(startTime: startTime)

        case .transcribing:
            TranscribingView()

        case .error(let message, _):
            ErrorView(message: message)
        }
    }

    // MARK: - Background Blur

    private var blurBackground: some View {
        // Use VisualEffectView wrapper for native .hudWindow blur
        VisualEffectView.hudStyle
            .clipShape(RoundedRectangle(cornerRadius: viewModel.currentState.cornerRadius))
    }
}

// MARK: - Preview

#Preview {
    @StateObject var viewModel = HUDViewModel()
    return HUDContentView(viewModel: viewModel)
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.3))
}
