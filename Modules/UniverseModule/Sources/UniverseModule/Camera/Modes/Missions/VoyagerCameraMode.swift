import CoreGraphics
import Foundation
import simd

/// Composes the same immutable flight sample used by the vehicle presenter.
final class VoyagerCameraMode {
    private var routeID: UUID?
    private var openingFrame: CameraTransition.Frame?

    func frame(state: NavigationRouteRenderState, viewportSize: CGSize,
               currentPose: CameraPose) -> CameraTransition.Frame? {
        guard let flight = state.voyagerFlight, let profile = state.route?.voyagerProfile else { return nil }
        if routeID != state.route?.id {
            routeID = state.route?.id
            openingFrame = CameraTransition.Frame(target: currentPose.target, distance: currentPose.distance,
                                                  orientation: currentPose.orientation,
                                                  preciseTarget: currentPose.preciseTarget)
        }
        let time = state.elapsedTime
        let position = flight.probe.precisePosition
        let isLaunch = time < 20
        let isEpilogue = time >= 64
        let localTarget = isLaunch || isEpilogue ? position : (position + flight.focusCenter) * 0.5
        let cruiseTarget = position * 0.5
        let weight = Double(flight.closeUpWeight)
        let target = cruiseTarget + (localTarget - cruiseTarget) * weight
        let localRadius: Float
        if isLaunch {
            localRadius = profile.earthRadius * 0.7
        } else if isEpilogue {
            localRadius = flight.vehicleScale * 3
        } else {
            localRadius = Float(distance(position, flight.focusCenter)) * 0.5 + flight.focusRadius * 1.3
        }
        let localDistance = CameraFit.distanceToFit(radius: localRadius, currentDistance: currentPose.distance,
                                                   viewportSize: viewportSize) * 1.35
        let cruiseDistance = CameraFit.distanceToFit(radius: Float(length(position)) * 0.6,
                                                    currentDistance: currentPose.distance, viewportSize: viewportSize)
        let distance = cruiseDistance * (1 - flight.closeUpWeight) + localDistance * flight.closeUpWeight
        let launchBackward = normalize(SIMD3<Float>(profile.launchDirection) + SIMD3<Float>(0.3, 0.3, 0.3))
        let launchBlend = VoyagerRouteProfile.smooth((time - 15) / 5)
        let backward = normalize(launchBackward * (1 - launchBlend) + SIMD3<Float>(0.3, 0.6, 1) * launchBlend)
        let right = normalize(cross(SIMD3<Float>(0, 1, 0), backward))
        let cameraUp = normalize(cross(backward, right))
        let orientation = simd_quatf(simd_float3x3(columns: (right, cameraUp, backward)))
        // Reserve the lower part of the viewport for progress and the epilogue caption.
        let composed = target - SIMD3<Double>(cameraUp * distance * tan(CameraFit.verticalFieldOfView / 2) * 0.35)
        let frame = CameraTransition.Frame(target: SIMD3<Float>(composed), distance: distance,
                                           orientation: orientation, preciseTarget: composed)
        guard time < 2, let openingFrame else { return frame }
        return CameraTransition.interpolate(from: openingFrame, to: frame,
                                             progress: VoyagerRouteProfile.smooth(time / 2))
    }
}
