import RealityKit
import Testing
@testable import UniverseModule

@MainActor
@Test func realityRibbonReusesMeshAndRetainsLastCompleteGeometry() throws {
    let ribbon = try RealityRibbon(maximumSegmentCount: 2)
    let entityIdentity = ObjectIdentifier(ribbon.entity)
    let points: [SIMD3<Float>] = [
        SIMD3<Float>(0, 0, 0),
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(1, 1, 0)
    ]

    ribbon.update(points: points,
                  sceneOrigin: .zero,
                  cameraPosition: SIMD3<Float>(0, 0, 4),
                  cameraUp: SIMD3<Float>(0, 1, 0),
                  color: SIMD4<Float>(0.2, 0.82, 1, 1))

    let model = try #require(ribbon.entity.components[ModelComponent.self])
    let mesh = try #require(model.mesh.lowLevelMesh)
    #expect(ribbon.entity.isEnabled)
    #expect(mesh.parts.count == 1)

    ribbon.update(points: points + [SIMD3<Float>(2, 1, 0)],
                  sceneOrigin: .zero,
                  cameraPosition: SIMD3<Float>(0, 0, 4),
                  cameraUp: SIMD3<Float>(0, 1, 0),
                  color: SIMD4<Float>(1, 0, 0, 1))

    #expect(ObjectIdentifier(ribbon.entity) == entityIdentity)
    #expect(ribbon.entity.isEnabled)
    #expect(mesh.parts.count == 1)
}

@MainActor
@Test func realityRibbonHidesOnlyForExplicitInactiveState() throws {
    let ribbon = try RealityRibbon(maximumSegmentCount: 2)
    ribbon.update(points: [SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0)],
                  sceneOrigin: .zero,
                  cameraPosition: SIMD3<Float>(0, 0, 4),
                  cameraUp: SIMD3<Float>(0, 1, 0),
                  color: SIMD4<Float>(1, 1, 1, 1))
    #expect(ribbon.entity.isEnabled)

    ribbon.hide()

    #expect(!ribbon.entity.isEnabled)
}

@MainActor
@Test func proceduralNavigationRouteColorUsesSubtleOpacity() {
    #expect(abs(RealityProceduralSceneContent.navigationRouteColor.w - 0.60) < 0.0001)
}

@Test func realityRibbonMaintainsScreenSpaceWidthAcrossCameraDepths() {
    let fov: Float = .pi / 3
    let viewportHeight: Float = 844
    let lineWidth: Float = 2.5
    let nearDepth: Float = 10
    let farDepth: Float = 20_000

    let nearHalfWidth = RealityRibbon.halfWidth(cameraSpaceDepth: nearDepth,
                                                 verticalFieldOfView: fov,
                                                 viewportHeight: viewportHeight,
                                                 lineWidth: lineWidth)
    let farHalfWidth = RealityRibbon.halfWidth(cameraSpaceDepth: farDepth,
                                                verticalFieldOfView: fov,
                                                viewportHeight: viewportHeight,
                                                lineWidth: lineWidth)

    #expect(abs(projectedLineWidth(halfWidth: nearHalfWidth,
                                   depth: nearDepth,
                                   fov: fov,
                                   viewportHeight: viewportHeight) - lineWidth) < 0.0001)
    #expect(abs(projectedLineWidth(halfWidth: farHalfWidth,
                                   depth: farDepth,
                                   fov: fov,
                                   viewportHeight: viewportHeight) - lineWidth) < 0.0001)
}

@Test func proceduralEnvironmentExpandsBeyondOuterTransferGeometry() {
    let farPlane: Float = 40_000
    let environmentRadius = RealityProceduralSceneContent.environmentScale(
        farPlane: farPlane
    ) * 9_000

    #expect(environmentRadius > 39_000)
    #expect(environmentRadius < farPlane)
}

@MainActor
@Test func proceduralOrbitCirclePointsUseRealityKitXZPlane() throws {
    let points = RealityProceduralSceneContent.circlePoints(center: SIMD3<Float>(10, 20, 30),
                                                            radius: 4)
    let firstPoint = try #require(points.first)
    let quarterPoint = points[points.count / 4]

    #expect(simd_distance(firstPoint, SIMD3<Float>(14, 20, 30)) < 0.0001)
    #expect(simd_distance(quarterPoint, SIMD3<Float>(10, 20, 26)) < 0.0001)
    #expect(points.allSatisfy { abs($0.y - 20) < 0.0001 })
}

@MainActor
@Test func realityStarFieldUsesOneBatchedLowLevelMesh() throws {
    let starField = try RealityStarField(configuration: StarFieldConfiguration(density: 0.01))
    let model = try #require(starField.entity.components[ModelComponent.self])
    let mesh = try #require(model.mesh.lowLevelMesh)

    starField.update(sceneOrigin: SIMD3<Float>(10, 20, 30),
                     cameraPosition: .zero,
                     cameraRight: SIMD3<Float>(1, 0, 0),
                     cameraUp: SIMD3<Float>(0, 1, 0),
                     simulationTime: 1)

    #expect(mesh.parts.count == 1)
    #expect(starField.entity.children.isEmpty)
}

private func projectedLineWidth(halfWidth: Float,
                                depth: Float,
                                fov: Float,
                                viewportHeight: Float) -> Float {
    halfWidth * viewportHeight / (depth * tan(fov / 2))
}
