//
//  VisualEffectView.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI
import AppKit

/// SwiftUI wrapper for NSVisualEffectView
/// Provides blur and vibrancy effects for HUD background
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

extension VisualEffectView {
    /// Default HUD style: dark blur
    static var hudStyle: VisualEffectView {
        VisualEffectView(
            material: .hudWindow,
            blendingMode: .behindWindow,
            state: .active
        )
    }
}
