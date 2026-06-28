import simd
import Testing
@testable import UniverseModule

@Test func routeProgressMapsToArcLengthPosition() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(10, 0, 0),
                                    SIMD3<Float>(10, 10, 0)
                                ],
                                cumulativeDistances: [0, 10, 20],
                                totalDistance: 20,
                                estimatedDuration: 12)

    #expect(route.point(at: 0) == SIMD3<Float>(0, 0, 0))
    #expect(route.point(at: 1) == SIMD3<Float>(10, 10, 0))

    let midpoint = try #require(route.point(at: 0.75))
    #expect(simd_distance(midpoint, SIMD3<Float>(10, 5, 0)) < 0.0001)
}

@Test func routePathReplacementPreservesIdentityAndDuration() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(1, 0, 0)
                                ],
                                cumulativeDistances: [0, 1],
                                totalDistance: 1,
                                estimatedDuration: 12)
    let updated = route.replacingPath(points: [
        SIMD3<Float>(2, 0, 0),
        SIMD3<Float>(2, 4, 0)
    ], cumulativeDistances: [0, 4], totalDistance: 4)

    #expect(updated.id == route.id)
    #expect(updated.estimatedDuration == route.estimatedDuration)
    #expect(updated.point(at: 1) == SIMD3<Float>(2, 4, 0))
}

@Test func routeReportsMotionDirectionOnStraightPath() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(10, 0, 0)
                                ],
                                cumulativeDistances: [0, 10],
                                totalDistance: 10,
                                estimatedDuration: 12)

    let direction = try #require(route.motionDirection(at: 0.4))

    #expect(simd_distance(direction, SIMD3<Float>(1, 0, 0)) < 0.0001)
    #expect(abs(route.distance(at: 0.4) - 4) < 0.0001)
    #expect(abs(route.remainingDistance(at: 0.4) - 6) < 0.0001)
}

@Test func routeReportsForwardMotionDirectionAtBentSegmentBoundary() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(10, 0, 0),
                                    SIMD3<Float>(10, 10, 0)
                                ],
                                cumulativeDistances: [0, 10, 20],
                                totalDistance: 20,
                                estimatedDuration: 12)

    let direction = try #require(route.motionDirection(at: 0.5))

    #expect(simd_distance(direction, SIMD3<Float>(0, 1, 0)) < 0.0001)
}

@Test func routeLookAheadPointClampsNearEnd() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(10, 0, 0),
                                    SIMD3<Float>(10, 10, 0)
                                ],
                                cumulativeDistances: [0, 10, 20],
                                totalDistance: 20,
                                estimatedDuration: 12)

    let lookAhead = try #require(route.lookAheadPoint(at: 0.9,
                                                      distance: 12))

    #expect(simd_distance(lookAhead, SIMD3<Float>(10, 10, 0)) < 0.0001)
}
