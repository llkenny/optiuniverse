import simd
import Testing
@testable import MetalModule

@Test func surfaceCameraModeTargetsBodyCenterAndPreservesDistance() throws {
    let mode = SurfaceCameraMode()
    let planet = surfaceCameraTestPacket(name: "Moon",
                                         worldPosition: SIMD3<Float>(2, 3, 4),
                                         radius: 0.5)
    let snapshot = PreparedRenderSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [planet])
    let currentPose = CameraPose(target: .zero,
                                 distance: 7,
                                 orientation: simd_quatf(angle: 0,
                                                          axis: SIMD3<Float>(0, 1, 0)))

    let frame = try #require(mode.makeSurfaceFrame(
        bodyName: "Moon",
        coordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                      longitudeDegrees: 0),
        snapshot: snapshot,
        currentPose: currentPose
    ))

    expectSurfaceVector(frame.target,
                 equals: planet.worldPosition)
    expectSurfaceEqual(frame.distance,
                currentPose.distance)
}

@Test func surfaceCameraModeAlignsCameraSurfacePointAndBodyCenter() throws {
    let mode = SurfaceCameraMode()
    let planet = surfaceCameraTestPacket(name: "Moon",
                                         worldPosition: SIMD3<Float>(2, 3, 4),
                                         radius: 0.5)
    let snapshot = PreparedRenderSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [planet])

    let frame = try #require(mode.makeSurfaceFrame(
        bodyName: "Moon",
        coordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                      longitudeDegrees: 0),
        snapshot: snapshot,
        currentPose: CameraPose(target: SIMD3<Float>(1, 0, 0),
                                distance: 4,
                                orientation: simd_quatf(angle: .pi / 5,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    ))
    let surfacePoint = SurfaceCoordinateMath.worldSurfacePoint(
        on: planet,
        at: SurfaceCoordinate(latitudeDegrees: -90,
                              longitudeDegrees: 0)
    )
    let cameraPosition = frame.target + frame.orientation.act(SIMD3<Float>(0, 0, frame.distance))
    let cameraToSurface = surfacePoint - cameraPosition
    let surfaceToCenter = planet.worldPosition - surfacePoint

    expectSurfaceEqual(simd_length(simd_cross(cameraToSurface, surfaceToCenter)),
                0,
                tolerance: 0.00001)
    #expect(simd_dot(simd_normalize(cameraToSurface),
                    simd_normalize(surfaceToCenter)) > 0.999)
}

@Test func surfaceCameraModeReturnsNilForMissingHostBody() {
    let mode = SurfaceCameraMode()
    let snapshot = PreparedRenderSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [])

    let frame = mode.makeSurfaceFrame(
        bodyName: "Moon",
        coordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                      longitudeDegrees: 0),
        snapshot: snapshot,
        currentPose: CameraPose(target: .zero,
                                distance: 4,
                                orientation: simd_quatf(angle: 0,
                                                         axis: SIMD3<Float>(0, 1, 0)))
    )

    #expect(frame == nil)
}

func surfaceCameraTestPacket(name: String,
                             worldPosition: SIMD3<Float>,
                             radius: Float) -> PreparedPlanetRenderPacket {
    let baseModelMatrix = float4x4.makeTranslation(worldPosition)
    return PreparedPlanetRenderPacket(
        planetName: name,
        meshes: [],
        baseModelMatrix: baseModelMatrix,
        worldModelMatrix: baseModelMatrix,
        normalizedScale: 1,
        primaryMeshRadius: radius,
        framingRadius: radius,
        surfaceRadius: radius,
        worldPosition: worldPosition
    )
}

func expectSurfaceVector(_ lhs: SIMD3<Float>,
                         equals rhs: SIMD3<Float>,
                         tolerance: Float = 0.00001) {
    expectSurfaceEqual(lhs.x,
                       rhs.x,
                       tolerance: tolerance)
    expectSurfaceEqual(lhs.y,
                       rhs.y,
                       tolerance: tolerance)
    expectSurfaceEqual(lhs.z,
                       rhs.z,
                       tolerance: tolerance)
}

func expectSurfaceEqual(_ lhs: Float,
                        _ rhs: Float,
                        tolerance: Float = 0.000001) {
    #expect(abs(lhs - rhs) <= tolerance)
}
