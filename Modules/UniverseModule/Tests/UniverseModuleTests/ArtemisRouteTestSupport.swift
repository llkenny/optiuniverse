import simd
import Testing
@testable import UniverseModule

func artemisSideDirection(originPosition: SIMD3<Float>,
                          waypointPosition: SIMD3<Float>) -> SIMD3<Float> {
    let majorVector = waypointPosition - originPosition
    let horizontalMajor = SIMD3<Float>(majorVector.x, 0, majorVector.z)
    guard simd_length_squared(horizontalMajor) > 0.000_001 else {
        return SIMD3<Float>(0, 1, 0)
    }

    return normalize(SIMD3<Float>(-horizontalMajor.z, 0, horizontalMajor.x))
}

func artemisLunarFlybyRadius(originPosition: SIMD3<Float>,
                             waypointPosition: SIMD3<Float>,
                             waypointSurfaceRadius: Float) -> Float {
    max(
        waypointSurfaceRadius * ArtemisRouteProfile.lunarFlybyRadiusScale,
        simd_distance(originPosition, waypointPosition) * ArtemisRouteProfile.lunarFlybyDistanceScale,
        0.01
    )
}

struct ArtemisLunarFlybyGeometry {
    let radius: Float
    let majorDirection: SIMD3<Float>
    let sideDirection: SIMD3<Float>
    let entry: SIMD3<Float>
    let exit: SIMD3<Float>
}

func artemisLunarFlybyGeometry(originPosition: SIMD3<Float>,
                               waypointPosition: SIMD3<Float>,
                               waypointSurfaceRadius: Float) -> ArtemisLunarFlybyGeometry {
    let majorVector = waypointPosition - originPosition
    let majorDistance = simd_length(majorVector)
    let majorDirection = majorDistance > 0.000_001
        ? majorVector / majorDistance
        : SIMD3<Float>(1, 0, 0)
    let sideDirection = artemisSideDirection(originPosition: originPosition,
                                             waypointPosition: waypointPosition)
    let sceneUp = SIMD3<Float>(0, 1, 0)
    let radius = artemisLunarFlybyRadius(originPosition: originPosition,
                                         waypointPosition: waypointPosition,
                                         waypointSurfaceRadius: waypointSurfaceRadius)
    let earthwardDirection = -majorDirection
    let entry = waypointPosition
        + earthwardDirection * radius * 1.45
        - sideDirection * radius * 0.58
        + sceneUp * radius * 0.04
    let exit = waypointPosition
        + earthwardDirection * radius * 1.42
        + sideDirection * radius * 0.62
        + sceneUp * radius * ArtemisRouteProfile.lunarFlybyTiltScale

    return ArtemisLunarFlybyGeometry(radius: radius,
                                     majorDirection: majorDirection,
                                     sideDirection: sideDirection,
                                     entry: entry,
                                     exit: exit)
}

func artemisLunarFlybyPoints(route: NavigationRoute,
                             geometry: ArtemisLunarFlybyGeometry,
                             sampleCount: Int) throws -> [SIMD3<Float>] {
    let flybyStartIndex = try #require(route.points.firstIndex {
        simd_distance($0, geometry.entry) < 0.000_1
    })
    let minimumCount = max(sampleCount, 48)
    let flybyCount = max(24, Int(Float(minimumCount) * ArtemisRouteProfile.lunarFlybySampleRatio))
    let loopEndIndex = try #require(route.points.indices.contains(flybyStartIndex + flybyCount - 1)
                                    ? flybyStartIndex + flybyCount - 1
                                    : nil)

    return Array(route.points[flybyStartIndex...loopEndIndex])
}

func expectArtemisLunarFlybyShape(route: NavigationRoute,
                                  geometry: ArtemisLunarFlybyGeometry,
                                  center: SIMD3<Float>,
                                  surfaceRadius: Float,
                                  sampleCount: Int) throws {
    let flybyPoints = try artemisLunarFlybyPoints(route: route,
                                                  geometry: geometry,
                                                  sampleCount: sampleCount)
    #expect(flybyPoints.count >= 20)
    #expect(simd_distance(try #require(flybyPoints.first), geometry.entry) < 0.000_1)
    #expect(simd_distance(try #require(flybyPoints.last), geometry.exit) < 0.000_1)
    #expect(artemisProjectedTurnSignChanges(points: flybyPoints,
                                            majorDirection: geometry.majorDirection,
                                            sideDirection: geometry.sideDirection) == 0)
    let minimumCenterDistance = route.points.map { simd_distance($0, center) }.min() ?? 0
    #expect(minimumCenterDistance > surfaceRadius * 1.05)
    #expect(minimumCenterDistance < geometry.radius)

    let lateralOffsets = flybyPoints.map { simd_dot($0 - center, geometry.sideDirection) }
    #expect((lateralOffsets.max() ?? 0) > geometry.radius * 0.55)
    #expect((lateralOffsets.min() ?? 0) < -geometry.radius * 0.5)

    let majorOffsets = flybyPoints.map { simd_dot($0 - center, geometry.majorDirection) }
    #expect((majorOffsets.max() ?? 0) > geometry.radius * 0.5)
    #expect((majorOffsets.min() ?? 0) < -geometry.radius * 0.6)
}

func artemisProjectedTurnSignChanges(points: [SIMD3<Float>],
                                     majorDirection: SIMD3<Float>,
                                     sideDirection: SIMD3<Float>) -> Int {
    guard points.count >= 3 else { return 0 }

    var previousSign: Float = 0
    var signChanges = 0
    for index in 1..<(points.count - 1) {
        let incoming = points[index] - points[index - 1]
        let outgoing = points[index + 1] - points[index]
        let incoming2D = SIMD2<Float>(simd_dot(incoming, majorDirection),
                                      simd_dot(incoming, sideDirection))
        let outgoing2D = SIMD2<Float>(simd_dot(outgoing, majorDirection),
                                      simd_dot(outgoing, sideDirection))
        let cross = incoming2D.x * outgoing2D.y - incoming2D.y * outgoing2D.x
        guard abs(cross) > 0.000_001 else {
            continue
        }
        let sign: Float = cross > 0 ? 1 : -1
        if previousSign != 0, sign != previousSign {
            signChanges += 1
        }
        previousSign = sign
    }

    return signChanges
}
