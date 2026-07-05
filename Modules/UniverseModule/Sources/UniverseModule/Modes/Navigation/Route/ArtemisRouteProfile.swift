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
    static let lunarEncounterProgress: Float = 0.58
    static let lunarFlybyCloseUpStartProgress: Float = 0.48
    static let lunarFlybyCloseUpPeakProgress: Float = lunarEncounterProgress
    static let lunarFlybyCloseUpEndProgress: Float = 0.7
    static let lunarFlybyMarkerBlend: Float = 0.38
    static let lunarFlybyCloseUpDistanceMultiplier: Float = 0.68
    static let minimumLunarFlybyCloseUpDuration: TimeInterval = 10
    static let earthLoopDistanceScale: Float = 0.1
    static let earthLoopRadiusScale: Float = 5.5
    static let lunarFlybyDistanceScale: Float = 0.03
    static let lunarFlybyRadiusScale: Float = 2.8
    static let lunarFlybyTiltScale: Float = 0.16
    static let returnBranchLateralScale: Float = 0.08
    static let earthLoopSampleRatio: Float = 0.14
    static let outboundSampleRatio: Float = 0.4
    static let lunarFlybySampleRatio: Float = 0.18

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

    static func lunarFlybyCloseUpProgress(routeProgress: Float) -> Float {
        guard routeProgress >= lunarFlybyCloseUpStartProgress,
              routeProgress <= lunarFlybyCloseUpEndProgress else {
            return 0
        }

        if routeProgress <= lunarFlybyCloseUpPeakProgress {
            let inboundDuration = max(lunarFlybyCloseUpPeakProgress - lunarFlybyCloseUpStartProgress,
                                      .leastNonzeroMagnitude)
            return easeInOutCubic((routeProgress - lunarFlybyCloseUpStartProgress) / inboundDuration)
        }

        let outboundDuration = max(lunarFlybyCloseUpEndProgress - lunarFlybyCloseUpPeakProgress,
                                   .leastNonzeroMagnitude)
        return 1 - easeInOutCubic((routeProgress - lunarFlybyCloseUpPeakProgress) / outboundDuration)
    }

    static func isLunarFlybyCloseUpActive(routeProgress: Float) -> Bool {
        lunarFlybyCloseUpProgress(routeProgress: routeProgress) > 0
    }

    static func routeProgress(linearProgress: Float,
                              estimatedDuration: TimeInterval) -> Float {
        let clampedProgress = simd_clamp(linearProgress, 0, 1)
        guard estimatedDuration > minimumLunarFlybyCloseUpDuration else {
            return clampedProgress
        }

        let closeUpStart = lunarFlybyCloseUpStartProgress
        let closeUpEnd = lunarFlybyCloseUpEndProgress
        let routeCloseUpWindow = closeUpEnd - closeUpStart
        let timeCloseUpWindow = simd_clamp(
            max(routeCloseUpWindow, Float(minimumLunarFlybyCloseUpDuration / estimatedDuration)),
            routeCloseUpWindow,
            1
        )
        let timeCloseUpCenter = (closeUpStart + closeUpEnd) * 0.5
        let timeCloseUpStart = simd_clamp(timeCloseUpCenter - timeCloseUpWindow * 0.5,
                                          0,
                                          1 - timeCloseUpWindow)
        let timeCloseUpEnd = timeCloseUpStart + timeCloseUpWindow

        if clampedProgress < timeCloseUpStart {
            return interpolate(from: 0,
                               to: closeUpStart,
                               progress: clampedProgress / max(timeCloseUpStart, .leastNonzeroMagnitude))
        }

        if clampedProgress <= timeCloseUpEnd {
            return interpolate(from: closeUpStart,
                               to: closeUpEnd,
                               progress: (clampedProgress - timeCloseUpStart) / timeCloseUpWindow)
        }

        return interpolate(from: closeUpEnd,
                           to: 1,
                           progress: (clampedProgress - timeCloseUpEnd)
                            / max(1 - timeCloseUpEnd, .leastNonzeroMagnitude))
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

    private static func interpolate(from start: Float,
                                    to end: Float,
                                    progress: Float) -> Float {
        start + (end - start) * simd_clamp(progress, 0, 1)
    }
}
