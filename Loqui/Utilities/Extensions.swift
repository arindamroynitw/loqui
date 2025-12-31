//
//  Extensions.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the fn key is pressed
    static let fnKeyPressed = Notification.Name("fnKeyPressed")

    /// Posted when the fn key is released
    static let fnKeyReleased = Notification.Name("fnKeyReleased")
}
