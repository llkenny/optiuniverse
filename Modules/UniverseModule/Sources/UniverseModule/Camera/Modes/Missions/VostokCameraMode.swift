import CoreGraphics
import Foundation
import simd

/// Keep the vehicle above the controls and open up to the Earth during the orbit.
final class VostokCameraMode {
    private var routeID: UUID?
    private var openingFrame: CameraTransition.Frame?

    func frame(state: NavigationRouteRenderState, viewportSize: CGSize,
               currentPose: CameraPose) -> CameraTransition.Frame? {
        guard let route = state.route, let profile = route.vostokProfile, let flight = state.vostokFlight else {
            return nil
        }
        let center = profile.preciseCenter
        if routeID != route.id {
            routeID = route.id
            let target = currentPose.preciseTarget - center
            openingFrame = CameraTransition.Frame(target: SIMD3<Float>(target), distance: currentPose.distance,
                                                  orientation: currentPose.orientation, preciseTarget: target)
        }
        let time = state.elapsedTime
        let orbit = Crew13RouteProfile.smooth(Float((time - 13) / 5))
            * (1 - Crew13RouteProfile.smooth(Float((time - 32) / 6)))
        let split = Crew13RouteProfile.smooth(Float((time - VostokFlightCue.ejection.rawValue) / 2))
        let capsule = flight.capsule.precisePosition
        let pilot = flight.pilot?.precisePosition ?? capsule
        let subject = capsule + (pilot - capsule) * Double(split) * 0.5
        let radial = flight.surfaceUp
        let tangent = normalize(cross(profile.normal, radial))
        let backward = normalize(radial * 0.88 - tangent * 0.48 + profile.normal * 0.43)
        let right = normalize(cross(radial, backward))
        let cameraUp = normalize(cross(backward, right))
        let orientation = simd_quatf(simd_float3x3(columns: (right, cameraUp, backward)))

        let launchSize = profile.radius * 0.21
        let descentSize = profile.vehicleSize(at: time) * 2 + Float(distance(capsule, pilot)) * 0.5
        let afterLaunch = Crew13RouteProfile.smooth(Float((time - 8) / 7))
        let closeSize = launchSize + (descentSize - launchSize) * afterLaunch
        let fitRadius = closeSize + (profile.radius * 1.12 - closeSize) * orbit
        let cameraDistance = CameraFit.distanceToFit(radius: fitRadius, currentDistance: currentPose.distance,
                                                     viewportSize: viewportSize)
        let target = subject + (center - subject) * Double(orbit) * 0.78
        let composed = target - SIMD3<Double>(cameraUp * cameraDistance * tan(CameraFit.verticalFieldOfView / 2) * 0.3)
        let frame = CameraTransition.Frame(target: SIMD3<Float>(composed), distance: cameraDistance,
                                           orientation: orientation, preciseTarget: composed)
        guard time < 2, let openingFrame else { return frame }
        let openingTarget = openingFrame.preciseTarget + center
        let start = CameraTransition.Frame(target: SIMD3<Float>(openingTarget), distance: openingFrame.distance,
                                           orientation: openingFrame.orientation, preciseTarget: openingTarget)
        return CameraTransition.interpolate(from: start, to: frame,
                                            progress: Crew13RouteProfile.smooth(Float(time / 2)))
    }
}
