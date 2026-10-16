import CoreGraphics
import simd
import Testing
@testable import UniverseModule

func makeNavigationCameraTestRoute() -> NavigationRoute {
    NavigationRoute(originName: "Earth",
                    destinationName: "Mars",
                    points: [
                        SIMD3<Float>(0, 0, 0),
                        SIMD3<Float>(2, 0, 0),
                        SIMD3<Float>(3, 0, 0)
                    ],
                    cumulativeDistances: [0, 2, 3],
                    totalDistance: 3,
                    estimatedDuration: 12,
                    overviewCenter: SIMD3<Float>(1.5, 0, 0))
}

func makeArtemisNavigationCameraTestRoute() -> NavigationRoute {
    let points = [
        SIMD3<Float>(0, 0, 0),
        SIMD3<Float>(1, 0, 1),
        SIMD3<Float>(2, 0, 0),
        SIMD3<Float>(1, 0, -1),
        SIMD3<Float>(0, 0, 0)
    ]
    let cumulativeDistances = RoutePathBuilder.makeCumulativeDistances(points: points)
    return NavigationRoute(originName: "Earth",
                           waypointName: "Moon",
                           destinationName: "Earth",
                           points: points,
                           cumulativeDistances: cumulativeDistances,
                           totalDistance: cumulativeDistances.last ?? 0,
                           estimatedDuration: 16,
                           overviewCenter: SIMD3<Float>(1, 0, 0))
}

func navigationCameraOverviewDistance(route: NavigationRoute,
                                      currentDistance: Float,
                                      viewportSize: CGSize) -> Float {
    OverviewCameraFraming.navigationOverviewDistance(route: route,
                                                     currentDistance: currentDistance,
                                                     viewportSize: viewportSize)
}

func manualNavigationModeState(route: NavigationRoute,
                               progress: Float,
                               elapsedTime: Double) -> CameraFrameModeState {
    CameraFrameModeState(
        transferPreviewActive: false,
        transfer: nil,
        navigation: NavigationRouteRenderState(route: route,
                                               progress: progress,
                                               elapsedTime: elapsedTime,
                                               isCameraAutoFramingEnabled: false)
    )
}

func expectNavigationCameraVector(_ lhs: SIMD3<Float>,
                                  equals rhs: SIMD3<Float>,
                                  tolerance: Float = 0.0001) {
    #expect(simd_distance(lhs, rhs) < tolerance)
}

func navigationCameraScreenPosition(point: SIMD3<Float>,
                                    pose: CameraPose,
                                    viewportSize: CGSize,
                                    projection: CameraProjectionParameters = CameraProjectionParameters(
                                        nearPlane: 0.1,
                                        farPlane: 100
                                     )) -> SIMD2<Float> {
    let aspect = Float(viewportSize.width / viewportSize.height)
    let projectionMatrix = float4x4.perspective(fov: projection.verticalFieldOfView,
                                                aspect: aspect,
                                                near: projection.nearPlane,
                                                far: projection.farPlane,
                                                verticalCenterOffset: projection.verticalCenterOffset)
    let clipPosition = projectionMatrix * pose.makeRenderViewMatrix() * SIMD4<Float>(point - pose.target, 1)

    return SIMD2<Float>(clipPosition.x / clipPosition.w,
                        clipPosition.y / clipPosition.w)
}

func expectNavigationCameraOrientation(_ lhs: simd_quatf,
                                       equals rhs: simd_quatf,
                                       tolerance: Float = 0.0001) {
    #expect(abs(abs(simd_dot(lhs.vector, rhs.vector)) - 1) < tolerance)
}

@MainActor
final class NavigationCameraSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?

    init(latestSnapshot: UniverseSceneSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Double) {}
}

extension UniverseSceneSnapshot {
    static var navigationCameraTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                              simulationTime: 0,
                              planets: [
                                navigationCameraTestPacket(name: "Sun",
                                                           worldPosition: SIMD3<Float>(100, 0, 0),
                                                           framingRadius: 1),
                                navigationCameraTestPacket(name: "Earth",
                                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                                           framingRadius: 0.1),
                                navigationCameraTestPacket(name: "Moon",
                                                           worldPosition: SIMD3<Float>(2, 0, 0),
                                                           framingRadius: 0.05),
                                navigationCameraTestPacket(name: "Mars",
                                                           worldPosition: SIMD3<Float>(4, 0, 0),
                                                           framingRadius: 0.2)
                              ])
    }

    static func navigationCameraTestPacket(name: String,
                                           worldPosition: SIMD3<Float>,
                                           framingRadius: Float) -> CelestialBodySnapshot {
        CelestialBodySnapshot(planetName: name,
                              baseModelMatrix: matrix_identity_float4x4,
                              normalizedScale: 1,
                              framingRadius: framingRadius,
                              surfaceRadius: framingRadius,
                              worldPosition: worldPosition)
    }
}
