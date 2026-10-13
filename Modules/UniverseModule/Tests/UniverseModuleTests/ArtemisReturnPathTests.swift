import simd
import Testing
@testable import UniverseModule

@Test(arguments: [24, 96, 192], [SIMD3<Float>(1, 0, 0), SIMD3<Float>(-1, 0.2, 1),
                               SIMD3<Float>(0, 1, 0), SIMD3<Float>(0.2, -1, -0.1)])
func artemisReturnDescendsOutsideEarth(sampleCount: Int, direction: SIMD3<Float>) throws {
    for radius: Float in [0.0006, 0.006378, 0.02] {
        let center = SIMD3<Float>(1, 0.2, -0.5)
        let moon = center + normalize(direction) * max(radius * 60, 0.2)
        let points = RoutePathBuilder.makeCislunarLoopPoints(
            originPosition: center, waypointPosition: moon,
            originSurfaceRadius: radius, waypointSurfaceRadius: radius * 0.27,
            destinationSurfaceRadius: radius, sampleCount: sampleCount
        )
        let major = normalize(moon - center)
        let side = artemisSideDirection(originPosition: center, waypointPosition: moon)
        let projectedSide = side - major * simd_dot(side, major)
        let entrySide = simd_length_squared(projectedSide) > 0.000_001
            ? normalize(projectedSide) : SIMD3<Float>(1, 0, 0)
        let entry = center - entrySide * radius * ArtemisRouteProfile.entryRadiusScale
        let entryIndex = try #require(points.firstIndex { simd_distance($0, entry) < radius * 0.001 })
        let end = try #require(points.last)
        let tolerance = max(radius * 0.0002, 0.000_0002)
        #expect(abs(simd_distance(end, center) - radius) < tolerance)
        let angle = acos(simd_clamp(simd_dot(normalize(entry - center), normalize(end - center)), -1, 1))
        #expect(abs(angle - .pi / 6) < 0.001)

        let flyby = artemisLunarFlybyGeometry(originPosition: center, waypointPosition: moon,
                                            waypointSurfaceRadius: radius * 0.27)
        let returnStart = try #require(points.firstIndex { simd_distance($0, flyby.exit) < tolerance })
        for index in (returnStart + 1)..<points.count {
            #expect(artemisSegmentClearance(points[index - 1], points[index], center: center)
                    >= radius - tolerance)
            if index > entryIndex {
                #expect(simd_distance(points[index], center)
                        <= simd_distance(points[index - 1], center) + tolerance)
            }
        }
        // Test the actual distance-based playback, rather than just stored vertices.
        let distances = RoutePathBuilder.makeCumulativeDistances(points: points)
        let totalDistance = try #require(distances.last)
        let route = NavigationRoute(originName: "Earth", waypointName: "Moon", destinationName: "Earth",
                                    points: points, cumulativeDistances: distances, totalDistance: totalDistance,
                                    estimatedDuration: 16)
        let returnProgress = distances[returnStart] / totalDistance
        for index in 0...1000 {
            let progress = returnProgress + (1 - returnProgress) * Float(index) / 1000
            let point = try #require(route.point(at: progress))
            #expect(simd_distance(point, center) >= radius - tolerance)
        }
        let incoming = normalize(points[entryIndex] - points[entryIndex - 1])
        let outgoing = normalize(points[entryIndex + 1] - points[entryIndex])
        #expect(simd_dot(incoming, outgoing) > 0.995)
        #expect(abs(simd_dot(incoming, normalize(entry - center))) < 0.1)
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
