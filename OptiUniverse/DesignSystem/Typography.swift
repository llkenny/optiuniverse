//
//  Typography.swift
//  OptiUniverse
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI

enum Typography {
    static let location = Font.system(size: 14, weight: .light)
    static let greeting = Font.system(size: 18, weight: .light)
    static let screenTitle = Font.system(size: 32, weight: .bold)

    static let chip = Font.system(size: 14)
    static let pageCardTitle = Font.system(size: 32, weight: .bold)
    static let pageCardCaption = Font.system(size: 12, weight: .semibold)
    static let destinationTitle = Font.system(size: 16, weight: .medium)
    static let destinationSubtitle = Font.system(size: 11, weight: .regular)

    static let overlayTitle = Font.system(size: 27)
    static let overlayHeading = Font.system(size: 16)
    static let overlayBody = Font.system(size: 14)
    static let overlayCaption = Font.system(size: 8)
    static let overlayValue = Font.system(size: 10)

    static let button = Font.system(size: 16)
    static let navigationTitle = Font.system(size: 15, weight: .semibold)
    static let navigationSubtitle = Font.system(size: 12)
    static let navigationMeta = Font.system(size: 14, weight: .medium)
    static let navigationControl = Font.system(size: 13, weight: .medium)
}
