import simd
import Testing
@testable import UniverseModule

@Test func surfaceCoordinateAxisConventions() {
    expectVector(SurfaceCoordinateMath.localUnitVector(
        for: SurfaceCoordinate(latitudeDegrees: 0,
                               longitudeDegrees: 0)
    ), equals: SIMD3<Float>(1, 0, 0))
    expectVector(SurfaceCoordinateMath.localUnitVector(
        for: SurfaceCoordinate(latitudeDegrees: 0,
                               longitudeDegrees: 90)
    ), equals: SIMD3<Float>(0, 1, 0))
    expectVector(SurfaceCoordinateMath.localUnitVector(
        for: SurfaceCoordinate(latitudeDegrees: 90,
                               longitudeDegrees: 42)
    ), equals: SIMD3<Float>(0, 0, 1))
    expectVector(SurfaceCoordinateMath.localUnitVector(
        for: SurfaceCoordinate(latitudeDegrees: -90,
                               longitudeDegrees: 42)
    ), equals: SIMD3<Float>(0, 0, -1))
}

@Test func surfaceCoordinateRoundTripsAwayFromPoles() throws {
    let coordinates = [
        SurfaceCoordinate(latitudeDegrees: 30,
                          longitudeDegrees: 45),
        SurfaceCoordinate(latitudeDegrees: -45,
                          longitudeDegrees: -135),
        SurfaceCoordinate(latitudeDegrees: 12.5,
                          longitudeDegrees: -47.25)
    ]

    for coordinate in coordinates {
        let vector = SurfaceCoordinateMath.localUnitVector(for: coordinate)
        let roundTrip = try #require(
            SurfaceCoordinateMath.coordinate(fromLocalUnitVector: vector)
        )

        expectEqual(roundTrip.latitudeDegrees,
                    coordinate.latitudeDegrees,
                    tolerance: 0.0001)
        expectEqual(roundTrip.longitudeDegrees,
                    coordinate.longitudeDegrees,
                    tolerance: 0.0001)
    }
}

@Test func surfaceRayIntersectsReferenceSphereFromOutside() throws {
    let planet = testSurfacePlanet()

    let hit = try #require(SurfaceCoordinateMath.referenceSphereIntersection(
        rayOrigin: SIMD3<Float>(0, 0, 3),
        rayDirection: SIMD3<Float>(0, 0, -1),
        planet: planet
    ))

    expectVector(hit.worldPoint,
                 equals: SIMD3<Float>(0, 0, 1))
    expectEqual(hit.distance,
                2)
    #expect(hit.isTangent == false)
}

@Test func surfaceRayMissesReferenceSphere() {
    let planet = testSurfacePlanet()

    let hit = SurfaceCoordinateMath.referenceSphereIntersection(
        rayOrigin: SIMD3<Float>(0, 0, 3),
        rayDirection: SIMD3<Float>(0, 1, 0),
        planet: planet
    )

    #expect(hit == nil)
}

@Test func surfaceRayReportsTangentReferenceSphereHit() throws {
    let planet = testSurfacePlanet()

    let hit = try #require(SurfaceCoordinateMath.referenceSphereIntersection(
        rayOrigin: SIMD3<Float>(1, 0, 3),
        rayDirection: SIMD3<Float>(0, 0, -1),
        planet: planet
    ))

    expectVector(hit.worldPoint,
                 equals: SIMD3<Float>(1, 0, 0))
    expectEqual(hit.distance,
                3)
    #expect(hit.isTangent)
}

@Test func surfaceRayIntersectsReferenceSphereFromInside() throws {
    let planet = testSurfacePlanet()

    let hit = try #require(SurfaceCoordinateMath.referenceSphereIntersection(
        rayOrigin: SIMD3<Float>(0, 0, 0),
        rayDirection: SIMD3<Float>(1, 0, 0),
        planet: planet
    ))

    expectVector(hit.worldPoint,
                 equals: SIMD3<Float>(1, 0, 0))
    expectEqual(hit.distance,
                1)
}

@Test func worldSurfacePointUsesBaseModelMatrixAndSurfaceRadius() throws {
    let baseModelMatrix = float4x4.makeTranslation(SIMD3<Float>(10, 20, 30))
    * float4x4.makeRotationZ(.pi / 2)
    let planet = testSurfacePlanet(baseModelMatrix: baseModelMatrix,
                                   surfaceRadius: 2)

    let worldPoint = SurfaceCoordinateMath.worldSurfacePoint(
        on: planet,
        at: SurfaceCoordinate(latitudeDegrees: 0,
                              longitudeDegrees: 0)
    )
    let coordinate = try #require(SurfaceCoordinateMath.coordinate(on: planet,
                                                                   forWorldPoint: worldPoint))

    expectVector(worldPoint,
                 equals: SIMD3<Float>(10, 22, 30))
    expectEqual(coordinate.latitudeDegrees,
                0)
    expectEqual(coordinate.longitudeDegrees,
                0)
}

private func testSurfacePlanet(baseModelMatrix: float4x4 = matrix_identity_float4x4,
                               surfaceRadius: Float = 1) -> PreparedPlanetRenderPacket {
    let worldPosition4 = baseModelMatrix * SIMD4<Float>(0, 0, 0, 1)
    return PreparedPlanetRenderPacket(
        planetName: "Test",
        meshes: [],
        baseModelMatrix: baseModelMatrix,
        worldModelMatrix: matrix_identity_float4x4,
        normalizedScale: 1,
        primaryMeshRadius: surfaceRadius,
        framingRadius: surfaceRadius,
        surfaceRadius: surfaceRadius,
        worldPosition: SIMD3<Float>(worldPosition4.x,
                                    worldPosition4.y,
                                    worldPosition4.z)
    )
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.00001) {
    expectEqual(lhs.x,
                rhs.x,
                tolerance: tolerance)
    expectEqual(lhs.y,
                rhs.y,
                tolerance: tolerance)
    expectEqual(lhs.z,
                rhs.z,
                tolerance: tolerance)
}

private func expectEqual(_ lhs: Float,
                         _ rhs: Float,
                         tolerance: Float = 0.000001) {
    #expect(abs(lhs - rhs) <= tolerance)
}
