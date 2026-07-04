//
//  ArtemisRouteProfile.swift
//  UniverseModule
//
//  Created by Codex on 03.07.2026.
//

import Foundation
import simd

enum ArtemisRouteProfile {
    static let openingDuration: Float = 2.5
    static let minimumOpeningPhaseEnd: Float = 0.1
    static let maximumOpeningPhaseEnd: Float = 0.2
    static let bodyAnchorClearanceScale: Float = 1.12
    static let overviewPaddingScale: Float = 1.2

    static func isArtemisRoute(originName: String,
                               waypointName: String?,
                               destinationName: String) -> Bool {
        originName == "Earth" &&
        waypointName == "Moon" &&
        destinationName == "Earth"
    }

    static func isArtemisRoute(_ route: NavigationRoute) -> Bool {
        isArtemisRoute(originName: route.originName,
                       waypointName: route.waypointName,
                       destinationName: route.destinationName)
    }

    static func openingPhaseEnd(estimatedDuration: TimeInterval) -> Float {
        guard estimatedDuration > 0 else {
            return minimumOpeningPhaseEnd
        }

        return simd_clamp(openingDuration / Float(estimatedDuration),
                          minimumOpeningPhaseEnd,
                          maximumOpeningPhaseEnd)
    }

    static func easedOpeningProgress(routeProgress: Float,
                                     estimatedDuration: TimeInterval) -> Float {
        let phaseEnd = openingPhaseEnd(estimatedDuration: estimatedDuration)
        return easeInOutCubic(routeProgress / phaseEnd)
    }

    static func anchorClearance(radius: Float,
                                maximumDistance: Float) -> Float {
        guard radius.isFinite,
              radius > 0,
              maximumDistance.isFinite,
              maximumDistance > 0 else {
            return 0
        }

        return min(radius * bodyAnchorClearanceScale,
                   maximumDistance * 0.2)
    }

    static func overviewPaddingRadius(originRadius: Float,
                                      waypointRadius: Float,
                                      destinationRadius: Float) -> Float {
        max(originRadius, waypointRadius, destinationRadius, 0) * overviewPaddingScale
    }

    private static func easeInOutCubic(_ value: Float) -> Float {
        let clampedValue = simd_clamp(value, 0, 1)
        if clampedValue < 0.5 {
            return 4 * clampedValue * clampedValue * clampedValue
        }

        let inverseProgress = -2 * clampedValue + 2
        return 1 - (inverseProgress * inverseProgress * inverseProgress) / 2
    }
}
