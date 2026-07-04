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

@Test func navigationCameraModeStartsArtemisRouteFromEarthCloseUp() throws {
    let mode = NavigationCameraMode()
    let route = makeArtemisNavigationCameraTestRoute()
    let currentPose = CameraPose(target: SIMD3<Float>(12, 3, 4),
                                 distance: 7,
                                 orientation: simd_quatf(angle: .pi / 4,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let transaction = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0,
                                          elapsedTime: 0),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    expectVector(try #require(transaction.cameraTarget),
                 equals: SIMD3<Float>(0, 0, 0))
    #expect(abs((transaction.cameraDistance ?? 0) - CameraFit.distanceToFit(
        radius: 0.1,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectOrientation(try #require(transaction.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@Test func navigationCameraModeZoomsArtemisRouteFromEarthToOverview() throws {
    let mode = NavigationCameraMode()
    let route = makeArtemisNavigationCameraTestRoute()
    let currentPose = CameraPose(target: SIMD3<Float>(12, 3, 4),
                                 distance: 7,
                                 orientation: simd_quatf(angle: .pi / 4,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let openingEndProgress: Float = 2.5 / 16.0
    let earthDistance = CameraFit.distanceToFit(radius: 0.1,
                                                currentDistance: currentPose.distance,
                                                viewportSize: viewportSize)
    let routeOverviewDistance = overviewDistance(route: route,
                                                 currentDistance: currentPose.distance,
                                                 viewportSize: viewportSize)
    let midpoint = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: openingEndProgress * 0.5,
                                          elapsedTime: 1.25),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let openingEnd = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: openingEndProgress,
                                          elapsedTime: 2.5),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    let midpointTarget = try #require(midpoint.cameraTarget)
    #expect(simd_distance(midpointTarget, SIMD3<Float>(0, 0, 0)) > 0.0001)
    #expect(simd_distance(midpointTarget, route.overviewCenter) > 0.0001)
    #expect((midpoint.cameraDistance ?? 0) > earthDistance)
    #expect((midpoint.cameraDistance ?? 0) < routeOverviewDistance)
    expectOrientation(try #require(midpoint.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)

    expectVector(try #require(openingEnd.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((openingEnd.cameraDistance ?? 0) - routeOverviewDistance) < 0.0001)
    expectOrientation(try #require(openingEnd.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@Test func navigationCameraModeMovesArtemisOpeningTargetThroughRouteMarker() throws {
    let mode = NavigationCameraMode()
    let route = makeArtemisNavigationCameraTestRoute()
    let currentPose = CameraPose(target: SIMD3<Float>(12, 3, 4),
                                 distance: 7,
                                 orientation: simd_quatf(angle: .pi / 4,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let openingEndProgress = ArtemisRouteProfile.openingPhaseEnd(
        estimatedDuration: route.estimatedDuration
    )
    let earlyProgress = openingEndProgress * 0.25
    let markerFocusProgress = openingEndProgress * 0.5

    let early = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: earlyProgress,
                                          elapsedTime: 0.625),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let markerFocused = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: markerFocusProgress,
                                          elapsedTime: 1.25),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    let earlyTarget = try #require(early.cameraTarget)
    let earlyMarker = try #require(route.point(at: earlyProgress))
    #expect(simd_distance(earlyTarget, SIMD3<Float>(0, 0, 0)) > 0.0001)
    #expect(simd_distance(earlyTarget, earlyMarker) < simd_distance(SIMD3<Float>(0, 0, 0),
                                                                   earlyMarker))

    let markerFocusTarget = try #require(markerFocused.cameraTarget)
    let markerPoint = try #require(route.point(at: markerFocusProgress))
    #expect(simd_distance(markerFocusTarget, markerPoint) <
            simd_distance(markerFocusTarget, route.overviewCenter))
    #expect(simd_distance(markerFocusTarget, route.overviewCenter) > 0.0001)
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

@Test func navigationCameraModeKeepsOverviewAtArrivalStartAndMovesTargetEarly() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let destinationPosition = SIMD3<Float>(4, 0, 0)
    let overviewFitDistance = overviewDistance(route: route,
                                               currentDistance: currentPose.distance,
                                               viewportSize: viewportSize)
    let arrivalStart = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.9,
                                          elapsedTime: 11),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let arrivalMiddle = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.925,
                                          elapsedTime: 11.1),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))

    expectVector(try #require(arrivalStart.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((arrivalStart.cameraDistance ?? 0) - overviewFitDistance) < 0.0001)

    let middleTarget = try #require(arrivalMiddle.cameraTarget)
    #expect(simd_distance(middleTarget, route.overviewCenter) > 0.1)
    #expect(simd_distance(middleTarget, destinationPosition) <
            simd_distance(route.overviewCenter, destinationPosition))
}

@Test func navigationCameraModeCentersDestinationAndCompletesZoomBeforeRouteEnd() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let destinationPosition = SIMD3<Float>(4, 0, 0)
    let destinationDistance = CameraFit.distanceToFit(
        radius: 0.2,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )
    let overviewFitDistance = overviewDistance(route: route,
                                               currentDistance: currentPose.distance,
                                               viewportSize: viewportSize)
    let arrivalNearlyDone = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.97,
                                          elapsedTime: 11.5),
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

    expectVector(try #require(arrivalNearlyDone.cameraTarget),
                 equals: destinationPosition)
    let nearlyDoneDistance = try #require(arrivalNearlyDone.cameraDistance)
    #expect(nearlyDoneDistance >= destinationDistance)
    #expect((nearlyDoneDistance - destinationDistance) /
            (overviewFitDistance - destinationDistance) < 0.02)

    expectVector(try #require(arrivalEnd.cameraTarget),
                 equals: destinationPosition)
    #expect(abs((arrivalEnd.cameraDistance ?? 0) - destinationDistance) < 0.0001)
    expectOrientation(try #require(arrivalEnd.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)
}

@Test func navigationCameraModeArrivalRecoveryStartsFromCapturedManualFrame() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let manualOrientation = simd_quatf(angle: .pi / 5,
                                       axis: SIMD3<Float>(0, 1, 0))
    let manualFrame = CameraTransition.Frame(target: SIMD3<Float>(8, 2, 1),
                                             distance: 6,
                                             orientation: manualOrientation)
    let transaction = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.92,
                                          elapsedTime: 11.1,
                                          isCameraAutoFramingEnabled: false),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: CGSize(width: 400, height: 400),
        currentPose: currentPose,
        arrivalRecovery: NavigationCameraMode.ArrivalRecovery(startFrame: manualFrame,
                                                              startProgress: 0.92)
    ))

    expectVector(try #require(transaction.cameraTarget),
                 equals: manualFrame.target)
    #expect(abs((transaction.cameraDistance ?? 0) - manualFrame.distance) < 0.0001)
    expectOrientation(try #require(transaction.cameraOrientation),
                      equals: manualOrientation)
}

@Test func navigationCameraModeArrivalRecoveryEndsAtCanonicalDestinationFrame() throws {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let currentPose = CameraPose(target: .zero,
                                 distance: 3,
                                 orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let canonicalArrivalEnd = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 1,
                                          elapsedTime: 12),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose
    ))
    let recoveryArrivalEnd = try #require(mode.makeNavigationTransaction(
        state: NavigationRouteRenderState(route: route,
                                          progress: 1,
                                          elapsedTime: 12,
                                          isCameraAutoFramingEnabled: false),
        snapshot: .navigationCameraTestSnapshot,
        viewportSize: viewportSize,
        currentPose: currentPose,
        arrivalRecovery: NavigationCameraMode.ArrivalRecovery(
            startFrame: CameraTransition.Frame(
                target: SIMD3<Float>(8, 2, 1),
                distance: 6,
                orientation: simd_quatf(angle: .pi / 5,
                                        axis: SIMD3<Float>(0, 1, 0))
            ),
            startProgress: 0.92
        )
    ))

    expectVector(try #require(recoveryArrivalEnd.cameraTarget),
                 equals: try #require(canonicalArrivalEnd.cameraTarget))
    #expect(abs((recoveryArrivalEnd.cameraDistance ?? 0) -
                (canonicalArrivalEnd.cameraDistance ?? 0)) < 0.0001)
    expectOrientation(try #require(recoveryArrivalEnd.cameraOrientation),
                      equals: try #require(canonicalArrivalEnd.cameraOrientation))
}

@Test func navigationCameraModeAppliesDestinationMinimumDistanceOnlyDuringArrival() {
    let mode = NavigationCameraMode()
    let route = makeNavigationCameraTestRoute()
    let baseMinimumDistance: Float = 0.001

    #expect(mode.minimumCameraDistance(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0,
                                          elapsedTime: 0),
        snapshot: .navigationCameraTestSnapshot,
        baseMinimumDistance: baseMinimumDistance
    ) == nil)
    #expect(mode.minimumCameraDistance(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.5,
                                          elapsedTime: 6),
        snapshot: .navigationCameraTestSnapshot,
        baseMinimumDistance: baseMinimumDistance
    ) == nil)
    #expect(mode.minimumCameraDistance(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.899,
                                          elapsedTime: 10),
        snapshot: .navigationCameraTestSnapshot,
        baseMinimumDistance: baseMinimumDistance
    ) == nil)

    let arrivalMinimumDistance = mode.minimumCameraDistance(
        state: NavigationRouteRenderState(route: route,
                                          progress: 0.9,
                                          elapsedTime: 11),
        snapshot: .navigationCameraTestSnapshot,
        baseMinimumDistance: baseMinimumDistance
    )

    #expect(abs((arrivalMinimumDistance ?? 0) - 0.21) < 0.0001)
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
    expectVector(cameraState.cameraTarget,
                 equals: manualPose.target)
    #expect(abs(cameraState.cameraDistance - manualPose.distance) < 0.0001)
    expectOrientation(cameraState.cameraOrientation,
                      equals: manualPose.orientation)

    coordinator.updateFrameCamera(
        snapshot: source.latestSnapshot,
        delta: 1.0 / 60.0,
        viewportSize: viewportSize,
        modeState: manualNavigationModeState(route: route,
                                             progress: 1,
                                             elapsedTime: 12)
    )

    expectVector(cameraState.cameraTarget,
                 equals: SIMD3<Float>(4, 0, 0))
    #expect(abs(cameraState.cameraDistance - destinationDistance) < 0.0001)
    expectOrientation(cameraState.cameraOrientation,
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

    expectVector(cameraState.cameraTarget,
                 equals: secondManualPose.target)
    #expect(abs(cameraState.cameraDistance - secondManualPose.distance) < 0.0001)
    expectOrientation(cameraState.cameraOrientation,
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

    expectVector(cameraState.cameraTarget,
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

private func makeArtemisNavigationCameraTestRoute() -> NavigationRoute {
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

private func overviewDistance(route: NavigationRoute,
                              currentDistance: Float,
                              viewportSize: CGSize) -> Float {
    OverviewCameraFraming.navigationOverviewDistance(route: route,
                                                     currentDistance: currentDistance,
                                                     viewportSize: viewportSize)
}

private func manualNavigationModeState(route: NavigationRoute,
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
