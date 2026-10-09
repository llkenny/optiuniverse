import CoreGraphics
import Foundation
import simd

/// Uses the renderer's sampled poses, framing both vehicles during the final approach.
final class Crew13CameraMode {
    private var routeID: UUID?
    private var openingFrame: CameraTransition.Frame?

    func frame(state: NavigationRouteRenderState, viewportSize: CGSize,
               currentPose: CameraPose) -> CameraTransition.Frame? {
        guard let route = state.route, let profile = route.crew13Profile,
              let flight = state.crew13Flight else { return nil }
        if routeID != route.id {
            routeID = route.id
            openingFrame = CameraTransition.Frame(target: currentPose.target - profile.center,
                                                   distance: currentPose.distance,
                                                   orientation: currentPose.orientation)
        }
        let approach = Crew13RouteProfile.smooth(Float((state.elapsedTime - 34) / 6))
        let midpoint = (flight.dragon.position + flight.station.position) * 0.5
        let target = simd_mix(flight.dragon.position, midpoint, SIMD3(repeating: approach))
        let radial = normalize(target - profile.center)
        // Look down from outside Earth and out of the orbital plane. Both the docking
        // axis and ISS's radial solar-array span remain visible from this direction.
        let tangent = normalize(cross(profile.normal, radial))
        let backward = normalize(radial * 0.85 + profile.normal * 0.55 - tangent * 0.55)
        let right = normalize(cross(radial, backward))
        let cameraUp = normalize(cross(backward, right))
        let orientation = simd_quatf(simd_float3x3(columns: (right, cameraUp, backward)))
        let pairRadius = distance(flight.dragon.position, flight.station.position) * 0.5
            + profile.stationScale * 3.2
        let subjectRadius = profile.radius * 0.22 * (1 - approach) + pairRadius * approach
        let cameraDistance = CameraFit.distanceToFit(radius: subjectRadius,
                                                     currentDistance: profile.radius * 1.5,
                                                     viewportSize: viewportSize) * 1.65
        // The navigation panel occupies the lower portion of the scene. Compose the
        // subjects in its upper half and leave enough vertical space for the ISS arrays.
        let composedTarget = target - cameraUp * cameraDistance * tan(CameraFit.verticalFieldOfView / 2) * 0.52
        let frame = CameraTransition.Frame(target: composedTarget, distance: cameraDistance, orientation: orientation)
        guard state.elapsedTime < 2, let openingFrame else { return frame }
        return CameraTransition.interpolate(
            from: CameraTransition.Frame(target: openingFrame.target + profile.center,
                                         distance: openingFrame.distance, orientation: openingFrame.orientation),
            to: frame, progress: Crew13RouteProfile.smooth(Float(state.elapsedTime / 2)))
    }
}
