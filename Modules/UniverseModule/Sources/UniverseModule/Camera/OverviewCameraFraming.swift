//
//  OverviewCameraFraming.swift
//  UniverseModule
//
//  Created by Codex on 02.07.2026.
//

import CoreGraphics
import simd

enum OverviewCameraFraming {
    static let orientation = simd_quatf(angle: -.pi * 0.25,
                                        axis: SIMD3<Float>(1, 0, 0))

    static func navigationRouteRadius(route: NavigationRoute) -> Float {
        let radius = route.points.reduce(Float(0)) { partialResult, point in
            max(partialResult, simd_distance(point, route.overviewCenter))
        }

        return max(radius + route.overviewPaddingRadius, 0.001)
    }

    static func navigationOverviewDistance(route: NavigationRoute,
                                           currentDistance: Float,
                                           viewportSize: CGSize) -> Float {
        CameraFit.distanceToFitWidth(radius: navigationRouteRadius(route: route),
                                     currentDistance: currentDistance,
                                     viewportSize: viewportSize)
    }

    static func navigationMaximumCameraDistance(route: NavigationRoute,
                                                currentDistance: Float,
                                                viewportSize: CGSize) -> Float {
        max(CameraState.defaultMaximumDistance,
            navigationOverviewDistance(route: route,
                                       currentDistance: currentDistance,
                                       viewportSize: viewportSize) * 1.2)
    }
}
