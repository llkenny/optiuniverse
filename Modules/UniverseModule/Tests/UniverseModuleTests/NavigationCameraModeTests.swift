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

    expectNavigationCameraVector(try #require(start.cameraTarget),
                 equals: SIMD3<Float>(0, 0, 0))
    #expect(abs((start.cameraDistance ?? 0) - CameraFit.distanceToFit(
        radius: 0.1,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectNavigationCameraOrientation(try #require(start.cameraOrientation),
                      equals: currentPose.orientation)
    expectNavigationCameraVector(try #require(departureEnd.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((departureEnd.cameraDistance ?? 0) - navigationCameraOverviewDistance(
        route: route,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectNavigationCameraOrientation(try #require(departureEnd.cameraOrientation),
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

    expectNavigationCameraVector(try #require(transaction.cameraTarget),
                 equals: SIMD3<Float>(0, 0, 0))
    #expect(abs((transaction.cameraDistance ?? 0) - CameraFit.distanceToFit(
        radius: 0.1,
        currentDistance: currentPose.distance,
        viewportSize: viewportSize
    )) < 0.0001)
    expectNavigationCameraOrientation(try #require(transaction.cameraOrientation),
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
    let routeOverviewDistance = navigationCameraOverviewDistance(route: route,
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
    expectNavigationCameraOrientation(try #require(midpoint.cameraOrientation),
                      equals: OverviewCameraFraming.orientation)

    expectNavigationCameraVector(try #require(openingEnd.cameraTarget),
                 equals: route.overviewCenter)
    #expect(abs((openingEnd.cameraDistance ?? 0) - routeOverviewDistance) < 0.0001)
    expectNavigationCameraOrientation(try #require(openingEnd.cameraOrientation),
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

@Test func artemisLunarFlybyCloseUpProgressHoldsFullFocusThroughFlybyCore() {
    let rampInProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: 0.50)
    let fullStartProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: 0.52)
    let encounterProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: 0.58)
    let fullEndProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: 0.66)
    let rampOutProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: 0.68)

    #expect(rampInProgress > 0)
    #expect(rampInProgress < 1)
    #expect(abs(fullStartProgress - 1) < 0.0001)
    #expect(abs(encounterProgress - 1) < 0.0001)
    #expect(abs(fullEndProgress - 1) < 0.0001)
    #expect(rampOutProgress > 0)
    #expect(rampOutProgress < 1)
}

@Test func navigationCameraModeFramesMoonCloseUpAlongRouteViewingDirection() throws {
    let mode = NavigationCameraMode()
    let route = makeArtemisNavigationCameraTestRoute()
    let currentPose = CameraPose(target: SIMD3<Float>(12, 3, 4),
                                 distance: 7,
                                 orientation: simd_quatf(angle: .pi / 4,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    let viewportSize = CGSize(width: 400, height: 400)
    let moonPosition = SIMD3<Float>(2, 0, 0)

    for progress in [Float(0.52), 0.58, 0.66] {
        let marker = try #require(route.point(at: progress))
        let transaction = try #require(mode.makeNavigationTransaction(
            state: NavigationRouteRenderState(route: route,
                                              progress: progress,
                                              elapsedTime: Double(progress) * route.estimatedDuration),
            snapshot: .navigationCameraTestSnapshot,
            viewportSize: viewportSize,
            currentPose: currentPose
        ))

        expectNavigationCameraVector(try #require(transaction.cameraTarget),
                     equals: moonPosition)

        let distance = try #require(transaction.cameraDistance)
        let orientation = try #require(transaction.cameraOrientation)
        let cameraPosition = moonPosition + orientation.act(SIMD3<Float>(0, 0, distance))
        let expectedDistance = min(simd_distance(marker, moonPosition), 0.05 * 4)
        #expect(abs(distance - expectedDistance) < 0.0001)

        let viewDirection = simd_normalize(moonPosition - cameraPosition)
        let markerToMoonDirection = simd_normalize(moonPosition - marker)
        #expect(simd_dot(viewDirection, markerToMoonDirection) > 0.999)
    }
}

@Test func artemisFlybyCameraKeepsContinuousOrientationThroughApproachAndDeparture() throws {
    // Exercise different Moon positions, including the quaternion wrap at +/- pi.
    for azimuthIndex in 0..<24 {
        let azimuth = Float(azimuthIndex) * .pi / 12
        let moon = SIMD3<Float>(2 * cos(azimuth), 0, 2 * sin(azimuth))
        let route = try #require(RoutePathBuilder().makeRoute(input: RouteBuildInput(
            originName: "Earth", waypointName: "Moon", destinationName: "Earth",
            planets: [], originPosition: .zero, waypointPosition: moon,
            originSurfaceRadius: 0.1, waypointSurfaceRadius: 0.05,
            destinationSurfaceRadius: 0.1, earthSunDirection: SIMD3<Float>(1, 0, 0),
            sunPosition: SIMD3<Float>(100, 0, 0), destinationPosition: .zero,
            estimatedDuration: 16
        )))
        let snapshot = UniverseSceneSnapshot(
            frameID: 1, simulationTime: 0,
            planets: [UniverseSceneSnapshot.navigationCameraTestPacket(
                name: "Moon", worldPosition: moon, framingRadius: 0.05
            )]
        )
        let mode = MissionCameraMode()
        var previous = OverviewCameraFraming.orientation
        var minimumAdjacentDot: Float = 1
        for step in 0...2400 {
            let progress = Float(0.47) + Float(step) * 0.0001
            let frame = mode.makeCruiseFrame(route: route, progress: progress,
                                            snapshot: snapshot, overviewDistance: 5)
            let orientation = frame?.orientation ?? OverviewCameraFraming.orientation
            minimumAdjacentDot = min(minimumAdjacentDot,
                                     abs(simd_dot(previous.vector, orientation.vector)))
            if progress >= 0.52, progress <= 0.66 {
                let frame = try #require(frame)
                let marker = try #require(route.point(at: progress))
                expectNavigationCameraVector(orientation.act(SIMD3<Float>(0, 0, 1)),
                             equals: simd_normalize(marker - moon))
                #expect(frame.distance <= 0.05 * 4 + 0.00001)
                #expect(orientation.act(SIMD3<Float>(0, 1, 0)).y > 0)
            }
            previous = orientation
        }
        // A small playback step must never produce a visible orientation jump.
        #expect(minimumAdjacentDot > cos(Float(0.05)), "Moon azimuth: \(azimuth)")
    }
}
