//
//  OptiColor.swift
//  OptiUniverse
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI

enum OptiColor {
    static let screenBackground = asset("Screen Background")

    static let textPrimary = asset("High emphasized")
    static let textSecondary = asset("Mid emphasized")
    static let textTertiary = asset("Low emphasized")

    static let controlSelected = asset("Enable")
    static let controlSelectedText = asset("Control Selected Text")
    static let controlDisabled = asset("Disable")
    static let controlInactiveStroke = asset("ChipInactiveStroke")
    static let controlActiveShadow = asset("Chip Active Shadow")

    static let overlayTextPrimary = asset("Neon Text Primary")
    static let overlayTextSecondary = asset("Neon Text Secondary")
    static let overlaySurface = asset("Neon Section Fill")
    static let overlayBorder = asset("Neon Section Border")

    static let buttonSurface = asset("Neon Button Fill")
    static let buttonBorder = asset("Neon Button Border")

    static let onImagePrimary = asset("On Image Primary")
    static let onImageSecondary = asset("On Image Secondary")
    static let imageScrim = asset("Image Scrim")

    private static func asset(_ name: String) -> Color {
        Color(name, bundle: .main)
    }
}
