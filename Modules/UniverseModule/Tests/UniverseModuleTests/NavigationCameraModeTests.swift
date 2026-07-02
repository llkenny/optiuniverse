import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@Test func navigationCameraModeMapsDeparturePhase() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: .pi / 4,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)

    let start = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0,
                                          elapsedTime: 0),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let departureEnd = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.1,
                                          elapsedTime: 1),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    expectVector(try #require(start.cameraTarget),
                 equals: SIMD3<Float>(0, 0, 0))
    #expect(abs((start.cameraDistance ?? 0) - CameraFit.distanceToFit(
        radius: 0.1,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectOrientation(try #require(start.cameraOrientation),
                      equals: currentPose.orientation)
    expectVector(try #require(departureEnd.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((departureEnd.cameraDistance ?? 0) - overviewDistance(
        route: route,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectOrientation(try #require(departureEnd.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@Test func navigationCameraModeUsesOverviewForMiddlePhase() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: .pi / 3,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let transaction = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.5,
                                          elapsedTime: 6),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    expectVector(try #require(transaction.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((transaction.cameraDistance ?? 0) - overviewDistance(
        route: route,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectOrientation(try #require(transaction.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@Test func navigationCameraModeMapsArrivalPhaseToLiveDestination() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let arrivalStart = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.9,
                                          elapsedTime: 11),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let arrivalEnd = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 1,
                                          elapsedTime: 12),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    expectVector(try #require(arrivalStart.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((arrivalStart.cameraDistance ?? 0) - overviewDistance(
        route: route,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectVector(try #require(arrivalEnd.cameraTarget),
                 equals: SIMD3<Float>(4, 0, 0))
    #expect(abs((arrivalEnd.cameraDistance ?? 0) - CameraFit.distanceToFit(
        radius: 0.2,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectOrientation(try #require(arrivalEnd.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@MainActor
@Test func cameraCoordinatorNavigationCommitsCameraAndSuppressesFollow() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let initialRevision = cameraState.revision
    let route = makeNavigationCameraTestRoute()
    let modeState = CameraFrameModeState(
        transferPreviewActive: false,
        transfer: nil,
        navigation: NavigationRouteRenderState(route: route,
                                               progress: 0.5,
                                               elapsedTime: 6)
    )

    coordinator.updateFrameCamera(snapshot: source.latestSnapshot,
                                  delta: 1.0 / 60.0,
                                  viewportSize: CGSize(width: 400, height: 400),
                                  modeState: modeState)

    #expect(cameraState.revision > initialRevision)
    expectVector(cameraState.cameraTarget,
                 equals: route.overviewCenter)
    #expect(cameraState.cameraTarget != SIMD3<Float>(100, 0, 0))
}

@MainActor
@Test func cameraCoordinatorNavigationAutoFramingDisabledPreservesManualView() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let route = makeNavigationCameraTestRoute()

    coordinator.makeRotation(with: CGPoint(x: 18, y: 9),
                             velocity: .zero)
    coordinator.makeScale(with: 2,
                          velocity: 0)
    let manualOrientation = cameraState.cameraOrientation
    let manualDistance = cameraState.cameraDistance

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: CGSize(width: 400, height: 400),
        modeState: CameraFrameModeState(
            transferPreviewActive: false,
            transfer: nil,
            navigation: NavigationRouteRenderState(route: route,
                                                   progress: 0.5,
                                                   elapsedTime: 6,
                                                   isCameraAutoFramingEnabled: false)
        )
    )

    expectOrientation(cameraState.cameraOrientation,
                      equals: manualOrientation)
    #expect(abs(cameraState.cameraDistance - manualDistance) < 0.0001)
    #expect(cameraState.cameraTarget != route.overviewCenter)
}

@Test func navigationOverviewRadiusUsesRouteDistanceFromOverviewCenter() {
    let totalDistance: Float = 4.236_068
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(-1, 0, 0),
                                    SIMD3<Float>(1, 0, 0),
                                    SIMD3<Float>(0, 0, -2)
                                ],
                                cumulativeDistances: [0, 2, totalDistance],
                                totalDistance: totalDistance,
                                estimatedDuration: 12,
                                overviewCenter: .zero)

    #expect(abs(OverviewCameraFraming.navigationRouteRadius(route: route) - 2) < 0.0001)
}

private func makeNavigationCameraTestRoute() -> NavigationRoute {
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

private func overviewDistance(route: NavigationRoute,
                              currentDistance: Float,
                              viewportSize: CGSize) -> Float {
    OverviewCameraFraming.navigationOverviewDistance(route: route,
                                                     currentDistance: currentDistance,
                                                     viewportSize: viewportSize)
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.0001) {
    #expect(simd_distance(lhs, rhs) < tolerance)
}

private func expectOrientation(_ lhs: simd_quatf,
                               equals rhs: simd_quatf,
                               tolerance: Float = 0.0001) {
    #expect(abs(abs(simd_dot(lhs.vector, rhs.vector)) - 1) < tolerance)
}

@MainActor
private final class NavigationCameraSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?

    init(latestSnapshot: UniverseSceneSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private extension UniverseSceneSnapshot {
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
