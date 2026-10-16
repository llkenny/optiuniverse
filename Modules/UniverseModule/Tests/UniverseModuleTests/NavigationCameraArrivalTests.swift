import CoreGraphics
import simd
import Testing
@testable import UniverseModule

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

    expectNavigationCameraVector(try #require(transaction.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((transaction.cameraDistance ?? 0) - navigationCameraOverviewDistance(
        route: route,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectNavigationCameraOrientation(try #require(transaction.cameraOrientation),
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
    let overviewFitDistance = navigationCameraOverviewDistance(route: route,
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

    expectNavigationCameraVector(try #require(arrivalStart.cameraTarget),
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
    let overviewFitDistance = navigationCameraOverviewDistance(route: route,
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

    expectNavigationCameraVector(try #require(arrivalNearlyDone.cameraTarget),
                 equals: destinationPosition)
    let nearlyDoneDistance = try #require(arrivalNearlyDone.cameraDistance)
    #expect(nearlyDoneDistance >= destinationDistance)
    #expect((nearlyDoneDistance - destinationDistance) /
            (overviewFitDistance - destinationDistance) < 0.02)

    expectNavigationCameraVector(try #require(arrivalEnd.cameraTarget),
                 equals: destinationPosition)
    #expect(abs((arrivalEnd.cameraDistance ?? 0) - destinationDistance) < 0.0001)
    expectNavigationCameraOrientation(try #require(arrivalEnd.cameraOrientation),
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

    expectNavigationCameraVector(try #require(transaction.cameraTarget),
                 equals: manualFrame.target)
    #expect(abs((transaction.cameraDistance ?? 0) - manualFrame.distance) < 0.0001)
    expectNavigationCameraOrientation(try #require(transaction.cameraOrientation),
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

    expectNavigationCameraVector(try #require(recoveryArrivalEnd.cameraTarget),
                 equals: try #require(canonicalArrivalEnd.cameraTarget))
    #expect(abs((recoveryArrivalEnd.cameraDistance ?? 0) -
                (canonicalArrivalEnd.cameraDistance ?? 0)) < 0.0001)
    expectNavigationCameraOrientation(try #require(recoveryArrivalEnd.cameraOrientation),
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
