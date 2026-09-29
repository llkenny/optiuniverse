import CoreGraphics
import Foundation
import simd

/// Mission framing follows the same sampled poses as the renderer, including the booster cutaway.
final class StarshipCameraMode {
    private var routeID: UUID?
    private var openingFrame: CameraTransition.Frame?

    func frame(state: NavigationRouteRenderState, viewportSize: CGSize,
               currentPose: CameraPose) -> CameraTransition.Frame? {
        guard let route = state.route, let profile = route.starshipProfile,
              let flight = state.starshipFlight else { return nil }
        if routeID != route.id {
            routeID = route.id
            openingFrame = CameraTransition.Frame(target: currentPose.target - profile.center,
                                                   distance: currentPose.distance,
                                                   orientation: currentPose.orientation)
        }
        let time = Float(state.elapsedTime)
        let boosterWeight = StarshipRouteProfile.smooth((time - 8) / 2)
            * (1 - StarshipRouteProfile.smooth((time - 16.5) / 2))
        let focus = simd_mix(flight.ship.position, flight.booster.position, SIMD3(repeating: boosterWeight))
        let radial = normalize(focus - profile.center)
        let overviewWeight = StarshipRouteProfile.smooth((time - 28) / 4)
            * (1 - StarshipRouteProfile.smooth((time - 40) / 4))
        let target = simd_mix(focus, profile.center, SIMD3(repeating: overviewWeight))
        // A positive radial offset always places the camera above the surface.
        let backward = normalize(radial * 0.65 + profile.normal * 0.75)
        let right = normalize(cross(radial, backward))
        let cameraUp = normalize(cross(backward, right))
        let orientation = simd_quatf(simd_float3x3(columns: (right, cameraUp, backward)))
        let overviewDistance = CameraFit.distanceToFit(radius: profile.radius * 1.5,
                                                       currentDistance: profile.radius * 5,
                                                       viewportSize: viewportSize)
        // Pull back while changing subjects so neither vehicle disappears outside a close-up.
        let subjectTransition = 4 * boosterWeight * (1 - boosterWeight)
        let closeDistance = profile.radius * (0.48 + 1.7 * subjectTransition)
        let distance = closeDistance * (1 - overviewWeight) + overviewDistance * overviewWeight
        let frame = CameraTransition.Frame(target: target, distance: distance, orientation: orientation)
        guard time < 2, let openingFrame else { return frame }
        return CameraTransition.interpolate(
            from: CameraTransition.Frame(target: openingFrame.target + profile.center,
                                         distance: openingFrame.distance, orientation: openingFrame.orientation),
            to: frame, progress: StarshipRouteProfile.smooth(time / 2))
    }
}
