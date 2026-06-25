//
//  StarTwinkle.swift
//  UniverseModule
//
//  Created by Codex on 08.06.2026.
//

enum StarTwinkle {
    static let base: Float = 0.97
    static let amplitude: Float = 0.03
    static let angularSpeed: Float = 0.42

    static var minimumFactor: Float {
        base - amplitude
    }

    static var maximumFactor: Float {
        base + amplitude
    }
}
