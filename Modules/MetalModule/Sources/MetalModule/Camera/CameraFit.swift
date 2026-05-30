//
//  CameraFit.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import CoreGraphics

enum CameraFit {
    static let verticalFieldOfView: Float = .pi / 3
    static let viewportFill: Float = 0.84
    static let defaultNearPlane: Float = 0.1
    static let defaultFarPlane: Float = 10000
    static let minimumNearPlane: Float = 0.0005

    static func distanceToFit(radius: Float,
                              currentDistance: Float,
                              viewportSize: CGSize) -> Float {
        guard radius > 0 else { return max(currentDistance, defaultNearPlane) }

        let width = max(Float(viewportSize.width), 1)
        let height = max(Float(viewportSize.height), 1)
        let aspect = width / height
        let horizontalFieldOfView = 2 * atan(tan(verticalFieldOfView / 2) * aspect)
        let limitingHalfFOV = min(verticalFieldOfView, horizontalFieldOfView) / 2
        let targetHalfAngle = atan(viewportFill * tan(limitingHalfFOV))
        let fittedDistance = radius / max(sin(targetHalfAngle), 0.001)

        return max(fittedDistance, radius * 1.05)
    }

    static func nearPlaneDistance(cameraDistance: Float,
                                  framingRadius: Float?) -> Float {
        guard let framingRadius else {
            return defaultNearPlane
        }

        let frontClearance = max(cameraDistance - framingRadius, minimumNearPlane * 2)
        return min(defaultNearPlane,
                   max(minimumNearPlane, frontClearance * 0.5))
    }
}
