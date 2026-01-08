//
//  ColorExtensions.swift
//  Loqui
//
//  Brand-exact color definitions and hex initializer
//  Colors from branding/README-v2.md
//

import SwiftUI
import AppKit

// MARK: - SwiftUI Color Extensions

extension Color {
    /// Primary brand color - Flow blue (#0080ff)
    static let hudBlue = Color(hex: "0080ff")

    /// Accent color - Electric cyan (#00bfff)
    static let hudCyan = Color(hex: "00bfff")

    /// Error color - SF Red (#ff3b30)
    static let hudRed = Color(hex: "ff3b30")

    /// Initialize Color from hex string
    /// - Parameter hex: Hex string (e.g., "0080ff" or "#0080ff")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - NSColor Extensions

extension NSColor {
    /// Primary brand color - Flow blue (#0080ff)
    static let hudBlue = NSColor(hex: "0080ff")

    /// Accent color - Electric cyan (#00bfff)
    static let hudCyan = NSColor(hex: "00bfff")

    /// Error color - SF Red (#ff3b30)
    static let hudRed = NSColor(hex: "ff3b30")

    /// Initialize NSColor from hex string
    /// - Parameter hex: Hex string (e.g., "0080ff" or "#0080ff")
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
