import simd
import Testing
@testable import UniverseModule

private let artemisReturnDirections: [SIMD3<Float>] = [
    SIMD3<Float>(1, 0, 0), SIMD3<Float>(-1, 0.2, 1),
    SIMD3<Float>(0, 1, 0), SIMD3<Float>(0.2, -1, -0.1),
    SIMD3<Float>(-0.0009, 1, 0), SIMD3<Float>(0.0009, 1, 0),
    SIMD3<Float>(-0.0009, -1, 0), SIMD3<Float>(0.0009, -1, 0),
    SIMD3<Float>(0, 1, -0.0009), SIMD3<Float>(0, 1, 0.0009),
    SIMD3<Float>(0, -1, -0.0009), SIMD3<Float>(0, -1, 0.0009),
    SIMD3<Float>(-0.0011, 1, 0), SIMD3<Float>(0.0011, 1, 0),
    SIMD3<Float>(-0.0011, -1, 0), SIMD3<Float>(0.0011, -1, 0)
]

@Test(arguments: [24, 96, 192], artemisReturnDirections)
func artemisReturnDescendsOutsideEarth(sampleCount: Int, direction: SIMD3<Float>) throws {
    for radius: Float in [0.0006, 0.006378, 0.02] {
        let center = SIMD3<Float>(1, 0.2, -0.5)
        let moon = center + normalize(direction) * max(radius * 60, 0.2)
        let points = RoutePathBuilder.makeCislunarLoopPoints(
            originPosition: center, waypointPosition: moon,
            originSurfaceRadius: radius, waypointSurfaceRadius: radius * 0.27,
            destinationSurfaceRadius: radius, sampleCount: sampleCount
        )
        let flyby = artemisLunarFlybyGeometry(originPosition: center, waypointPosition: moon,
                                            waypointSurfaceRadius: radius * 0.27)
        let tolerance = max(radius * 0.0002, 0.000_0002)
        let returnStart = try #require(points.firstIndex { simd_distance($0, flyby.exit) < tolerance })
        try expectArtemisReturnGeometry(Array(points[returnStart...]), center: center, radius: radius)
    }
}

@Test(arguments: [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1),
                  SIMD3<Float>(-1, 0, 0), SIMD3<Float>(0, -1, 0), SIMD3<Float>(0, 0, -1),
                  SIMD3<Float>(1, 2, 0.1)], [24, 96, 192])
func artemisReturnHandlesParallelAxes(direction: SIMD3<Float>, sampleCount: Int) throws {
    let major = normalize(direction)
    let points = ArtemisReturnPath(center: .zero, surfaceRadius: 0.02,
                                   majorDirection: major, sideDirection: major, controlScale: 0.2).makePoints(
        start: major * 0.2, controlA: major * 0.15, sampleCount: sampleCount)
    try expectArtemisReturnGeometry(points, center: .zero, radius: 0.02)
    let endpoint = try #require(points.last)
    #expect(abs(simd_length(endpoint) / 0.02 - 1) < 0.000_001)
}

private func expectArtemisReturnGeometry(_ points: [SIMD3<Float>], center: SIMD3<Float>,
                                         radius: Float) throws {
    let tolerance = max(radius * 0.0002, 0.000_0002)
    let entryRadius = radius * ArtemisRouteProfile.entryRadiusScale
    let entryIndex = try #require(points.indices.min {
        abs(simd_distance(points[$0], center) - entryRadius)
            < abs(simd_distance(points[$1], center) - entryRadius)
    })
    try #require(entryIndex > 0 && entryIndex < points.count - 1)
    let entry = points[entryIndex] - center
    let end = try #require(points.last) - center
    #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
    #expect(abs(simd_length(entry) - entryRadius) < tolerance)
    #expect(abs(simd_length(end) - radius) < tolerance)
    let angle = acos(simd_clamp(simd_dot(normalize(entry), normalize(end)), -1, 1))
    #expect(abs(angle - .pi / 6) < 0.001)
    for index in 1..<points.count {
        #expect(artemisSegmentClearance(points[index - 1], points[index], center: center) >= radius - tolerance)
        if index > entryIndex {
            #expect(simd_distance(points[index], center) <= simd_distance(points[index - 1], center) + tolerance)
        }
    }
    let incoming = normalize(points[entryIndex] - points[entryIndex - 1])
    let outgoing = normalize(points[entryIndex + 1] - points[entryIndex])
    #expect(simd_dot(incoming, outgoing) > 0.995)
    #expect(abs(simd_dot(incoming, normalize(entry))) < 0.1)
    let distances = RoutePathBuilder.makeCumulativeDistances(points: points)
    let totalDistance = try #require(distances.last)
    let route = NavigationRoute(originName: "Earth", waypointName: "Moon", destinationName: "Earth",
                                points: points, cumulativeDistances: distances, totalDistance: totalDistance,
                                estimatedDuration: 16)
    // Test distance-based playback across the complete return, including the final descent.
    for index in 0...1000 {
        let point = try #require(route.point(at: Float(index) / 1000))
        #expect(simd_distance(point, center) >= radius - tolerance)
    }
}

func artemisSegmentClearance(_ start: SIMD3<Float>, _ end: SIMD3<Float>, center: SIMD3<Float>) -> Float {
    let offset = start - center
    let segment = end - start
    let lengthSquared = simd_length_squared(segment)
    let progress = lengthSquared > 0 ? simd_clamp(-simd_dot(offset, segment) / lengthSquared, 0, 1) : 0
    return simd_length(offset + segment * progress)
}

@Test func artemisReturnWithoutSurfaceMetricsRemainsFinite() throws {
    let points = RoutePathBuilder.makeCislunarLoopPoints(originPosition: SIMD3<Float>(1, 0, 0),
                                                        waypointPosition: SIMD3<Float>(1.2, 0, 0))
    #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
    #expect(try #require(points.last) == SIMD3<Float>(1, 0, 0))
}
