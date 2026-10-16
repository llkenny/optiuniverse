import CoreGraphics
import simd
import Testing
@testable import UniverseModule

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
    expectNavigationCameraVector(cameraState.cameraTarget,
                 equals: route.overviewCenter)
    #expect(cameraState.cameraTarget != SIMD3<Float>(100, 0, 0))
}

@MainActor
@Test func cameraCoordinatorNavigationHandoffPreservesMarkerScreenPosition() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let route = makeNavigationCameraTestRoute()
    let viewportSize = CGSize(width: 400, height: 400)
    let progress: Float = 0.25
    let marker = try #require(route.point(at: progress))
    let navigationState = NavigationRouteRenderState(route: route,
                                                     progress: progress,
                                                     elapsedTime: 3)
    let expectedNavigationPose = try expectedNavigationCameraPose(state: navigationState,
                                                                 snapshot: source.latestSnapshot,
                                                                 viewportSize: viewportSize,
                                                                 currentPose: cameraState.pose)
    let initialMarkerScreenPosition = navigationCameraScreenPosition(point: marker,
                                                              pose: expectedNavigationPose,
                                                              viewportSize: viewportSize)

    coordinator.handOffNavigationCameraControl(navigation: navigationState,
                                               snapshot: source.latestSnapshot,
                                               viewportSize: viewportSize)
    let handoffPose = cameraState.pose

    #expect(simd_distance(marker, route.overviewCenter) > 0.0001)
    #expect(simd_distance(cameraState.cameraTarget, marker) > 0.0001)
    expectNavigationCameraVector(handoffPose.position,
                 equals: expectedNavigationPose.position)
    expectNavigationCameraVector(SIMD3<Float>(navigationCameraScreenPosition(point: marker,
                                                      pose: handoffPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))

    let markerDistanceBeforeRotation = simd_distance(marker, cameraState.pose.position)
    coordinator.makeRotation(with: CGPoint(x: 0, y: 12),
                             velocity: .zero)
    let rotatedPose = cameraState.pose

    expectNavigationCameraVector(SIMD3<Float>(navigationCameraScreenPosition(point: marker,
                                                      pose: rotatedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))
    #expect(simd_distance(rotatedPose.position, handoffPose.position) > 0.0001)
    #expect(abs(simd_distance(marker, rotatedPose.position) - markerDistanceBeforeRotation) < 0.0001)

    try expectRefreshedNavigationHandoff(
        context: NavigationHandoffTestContext(coordinator: coordinator, route: route,
                                              viewportSize: viewportSize, progress: progress,
                                              markerScreenPosition: initialMarkerScreenPosition,
                                              snapshot: source.latestSnapshot),
        rotatedPose: rotatedPose
    )
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

    expectNavigationCameraOrientation(cameraState.cameraOrientation,
                      equals: manualOrientation)
    #expect(abs(cameraState.cameraDistance - manualDistance) < 0.0001)
    #expect(cameraState.cameraTarget != route.overviewCenter)
}

@MainActor
@Test func cameraCoordinatorNavigationAutoFramingDisabledRecoversDuringArrival() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let route = makeNavigationCameraTestRoute()
    let viewportSize = CGSize(width: 400, height: 400)
    let destinationDistance = CameraFit.distanceToFit(radius: 0.2,
                                                      currentDistance: cameraState.cameraDistance,
                                                      viewportSize: viewportSize)

    coordinator.makeRotation(with: CGPoint(x: 18, y: 9),
                             velocity: .zero)
    coordinator.makeScale(with: 2,
                          velocity: 0)
    let manualPose = cameraState.pose

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: manualNavigationModeState(route: route,
                                             progress: 0.9,
                                             elapsedTime: 11)
    )
    expectNavigationCameraVector(cameraState.cameraTarget,
                 equals: manualPose.target)
    #expect(abs(cameraState.cameraDistance - manualPose.distance) < 0.0001)
    expectNavigationCameraOrientation(cameraState.cameraOrientation,
                      equals: manualPose.orientation)

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: manualNavigationModeState(route: route,
                                             progress: 1,
                                             elapsedTime: 12)
    )

    expectNavigationCameraVector(cameraState.cameraTarget,
                 equals: SIMD3<Float>(4, 0, 0))
    #expect(abs(cameraState.cameraDistance - destinationDistance) < 0.0001)
    expectNavigationCameraOrientation(cameraState.cameraOrientation,
                      equals: OverviewCameraFraming.orientation)
}

@MainActor
@Test func cameraCoordinatorNavigationArrivalRecoveryRestartsAfterManualControl() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let route = makeNavigationCameraTestRoute()
    let viewportSize = CGSize(width: 400, height: 400)

    coordinator.makeRotation(with: CGPoint(x: 18, y: 9),
                             velocity: .zero)
    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: manualNavigationModeState(route: route,
                                             progress: 0.9,
                                             elapsedTime: 11)
    )

    coordinator.beginManualCameraControl()
    coordinator.makeTranslation(with: CGPoint(x: 40, y: 20),
                                viewportSize: viewportSize)
    let secondManualPose = cameraState.pose

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: manualNavigationModeState(route: route,
                                             progress: 0.95,
                                             elapsedTime: 11.5)
    )

    expectNavigationCameraVector(cameraState.cameraTarget,
                 equals: secondManualPose.target)
    #expect(abs(cameraState.cameraDistance - secondManualPose.distance) < 0.0001)
    expectNavigationCameraOrientation(cameraState.cameraOrientation,
                      equals: secondManualPose.orientation)
}

@MainActor
@Test func cameraCoordinatorNavigationArrivalUsesDestinationMinimumDistance() throws {
    let source = NavigationCameraSnapshotSource(latestSnapshot: .navigationCameraTestSnapshot)
    let cameraState = CameraState()
    let snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: cameraState,
                                        snapshotProvider: snapshotProvider)
    let route = makeNavigationCameraTestRoute()
    let viewportSize = CGSize(width: 400, height: 400)
    let destinationDistance = CameraFit.distanceToFit(radius: 0.2,
                                                      currentDistance: cameraState.cameraDistance,
                                                      viewportSize: viewportSize)
    let sunMinimumDistance: Float = 1.05

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: CameraFrameModeState(
            transferPreviewActive: false,
            transfer: nil,
            navigation: NavigationRouteRenderState(route: route,
                                                   progress: 1,
                                                   elapsedTime: 12)
        )
    )

    expectNavigationCameraVector(cameraState.cameraTarget,
                 equals: SIMD3<Float>(4, 0, 0))
    #expect(abs(cameraState.cameraDistance - destinationDistance) < 0.0001)
    #expect(cameraState.cameraDistance < sunMinimumDistance)
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

@Test func navigationOverviewRadiusIncludesCislunarBodyPadding() {
    let route = NavigationRoute(originName: "Earth",
                                waypointName: "Moon",
                                destinationName: "Earth",
                                points: [
                                    SIMD3<Float>(-1, 0, 0),
                                    SIMD3<Float>(1, 0, 0)
                                ],
                                cumulativeDistances: [0, 2],
                                totalDistance: 2,
                                estimatedDuration: 16,
                                overviewPaddingRadius: 0.25,
                                overviewCenter: .zero)

    #expect(abs(OverviewCameraFraming.navigationRouteRadius(route: route) - 1.25) < 0.0001)
}

private func expectedNavigationCameraPose(state: NavigationRouteRenderState,
                                          snapshot: UniverseSceneSnapshot?,
                                          viewportSize: CGSize, currentPose: CameraPose) throws -> CameraPose {
    let expectedTransaction = try #require(NavigationCameraMode().makeNavigationTransaction(
        state: state,
        snapshot: snapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let expectedNavigationPose = CameraPose(
        target: try #require(expectedTransaction.cameraTarget),
        distance: try #require(expectedTransaction.cameraDistance),
        orientation: try #require(expectedTransaction.cameraOrientation)
    )
    return expectedNavigationPose
}

private struct NavigationHandoffTestContext {
    let coordinator: CameraCoordinator
    let route: NavigationRoute
    let viewportSize: CGSize
    let progress: Float
    let markerScreenPosition: SIMD2<Float>
    let snapshot: UniverseSceneSnapshot?
}

@MainActor
private func expectRefreshedNavigationHandoff(context: NavigationHandoffTestContext,
                                              rotatedPose: CameraPose) throws {
    let coordinator = context.coordinator
    let route = context.route
    let viewportSize = context.viewportSize
    let progress = context.progress
    let initialMarkerScreenPosition = context.markerScreenPosition
    let markerDelta = SIMD3<Float>(0.18, -0.07, 0.04)
    let refreshedRoute = route.replacingPath(
        points: route.points.map { $0 + markerDelta },
        cumulativeDistances: route.cumulativeDistances,
        totalDistance: route.totalDistance,
        overviewPaddingRadius: route.overviewPaddingRadius,
        overviewCenter: route.overviewCenter + markerDelta
    )
    let refreshedMarker = try #require(refreshedRoute.point(at: progress))

    coordinator.handOffNavigationCameraControl(
        navigation: NavigationRouteRenderState(route: refreshedRoute,
                                               progress: progress,
                                               elapsedTime: 3,
                                               isCameraAutoFramingEnabled: false),
        snapshot: context.snapshot,
        viewportSize: viewportSize
    )
    let refreshedPose = coordinator.currentCameraPose

    expectNavigationCameraVector(refreshedPose.target,
                 equals: rotatedPose.target + markerDelta)
    expectNavigationCameraVector(refreshedPose.position,
                 equals: rotatedPose.position + markerDelta)
    expectNavigationCameraVector(SIMD3<Float>(navigationCameraScreenPosition(point: refreshedMarker,
                                                      pose: refreshedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))
    expectNavigationCameraOrientation(coordinator.currentCameraPose.orientation,
                      equals: rotatedPose.orientation)

    let markerDistanceBeforeZoom = simd_distance(refreshedMarker, coordinator.currentCameraPose.position)
    coordinator.makeScale(with: 1.2,
                          velocity: 0)
    let zoomedPose = coordinator.currentCameraPose

    expectNavigationCameraVector(SIMD3<Float>(navigationCameraScreenPosition(point: refreshedMarker,
                                                      pose: zoomedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))
    #expect(simd_distance(refreshedMarker, zoomedPose.position) < markerDistanceBeforeZoom)
}
