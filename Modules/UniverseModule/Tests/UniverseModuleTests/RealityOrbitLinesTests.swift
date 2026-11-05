import RealityKit
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func orbitLinesStartHiddenAndSkipMeshUpdatesUntilEnabled() throws {
    let presenter = try RealityOrbitLines()
    let earth = try #require(presenter.ribbons[.earth]?.entity)
    let mesh = try #require(earth.model?.mesh.lowLevelMesh)
    presenter.update(snapshot: orbitLineScene(), transfer: .inactive, context: orbitLineContext())
    #expect(!presenter.root.isEnabled)
    #expect(!earth.isEnabled)
    #expect(mesh.parts.isEmpty)

    presenter.setVisible(true)
    presenter.update(snapshot: orbitLineScene(), transfer: .inactive, context: orbitLineContext())
    let originalVertex = try firstOrbitVertex(in: earth)
    #expect(presenter.root.isEnabled && earth.isEnabled)

    presenter.setVisible(false)
    var changedScene = orbitLineScene()
    changedScene.orbits = changedScene.orbits.map { orbit in
        CelestialOrbitSnapshot(body: orbit.body, parent: orbit.parent,
                               samples: orbit.samples.map {
                                   .init(epoch: $0.epoch, position: $0.position + SIMD3(5, 0, 0))
                               })
    }
    presenter.update(snapshot: changedScene, transfer: .inactive, context: orbitLineContext())
    #expect(!earth.isEnabled)
    #expect(try firstOrbitVertex(in: earth) == originalVertex)

    presenter.setVisible(true)
    presenter.update(snapshot: changedScene, transfer: .inactive, context: orbitLineContext())
    #expect(earth.isEnabled)
    #expect(try firstOrbitVertex(in: earth) != originalVertex)
    #expect(presenter.ribbons[.earth]?.entity === earth)
}

@MainActor
private func firstOrbitVertex(in entity: ModelEntity) throws -> SIMD3<Float> {
    let mesh = try #require(entity.model?.mesh.lowLevelMesh)
    var position = SIMD3<Float>.zero
    mesh.withUnsafeBytes(bufferIndex: 0) { buffer in
        position = buffer.load(as: SIMD3<Float>.self)
    }
    return position
}

@MainActor
@Test func orbitLinesReuseEntitiesAndSuppressOnlyVisibleTransferGuides() throws {
    let presenter = try RealityOrbitLines()
    presenter.setVisible(true)
    let scene = orbitLineScene()
    let context = orbitLineContext()
    presenter.update(snapshot: scene, transfer: .inactive, context: context)
    #expect(presenter.root.children.count == 10)
    #expect(presenter.ribbons[.sun] == nil)
    let earth = try #require(presenter.ribbons[.earth]?.entity)
    let mars = try #require(presenter.ribbons[.mars]?.entity)
    let moon = try #require(presenter.ribbons[.moon]?.entity)
    let mesh = try #require(earth.model?.mesh.lowLevelMesh)
    #expect(earth.isEnabled && mars.isEnabled && moon.isEnabled)

    // Guide-only state occurs before the asynchronous transfer solution is ready.
    let transfer = TransferOrbitRenderState(transferOrbit: nil,
                                             preciseEarthOrbitPoints: [SIMD3(1, 0, 0), SIMD3(2, 0, 0)],
                                             preciseDestinationOrbitPoints: [SIMD3(2, 0, 0), SIMD3(3, 0, 0)],
                                             destinationName: "Mars")
    presenter.update(snapshot: scene, transfer: transfer, context: context)
    #expect(!earth.isEnabled && !mars.isEnabled && moon.isEnabled)
    presenter.update(snapshot: scene, transfer: .inactive, context: context)
    #expect(earth.isEnabled && mars.isEnabled && moon.isEnabled)
    #expect(presenter.ribbons[.earth]?.entity === earth)
    #expect(earth.model?.mesh.lowLevelMesh?.vertexCapacity == mesh.vertexCapacity)
    #expect(mesh.parts.count == 1)

    presenter.update(snapshot: nil, transfer: .inactive, context: context)
    #expect(presenter.ribbons.values.allSatisfy { !$0.entity.isEnabled })
}

@MainActor
@Test func orbitLinesHideMissingAndInvalidGeometryInsteadOfRetainingOldMeshes() throws {
    let presenter = try RealityOrbitLines()
    presenter.setVisible(true)
    var scene = orbitLineScene()
    presenter.update(snapshot: scene, transfer: .inactive, context: orbitLineContext())
    #expect(presenter.ribbons[.earth]?.entity.isEnabled == true)
    scene.orbits = [CelestialOrbitSnapshot(body: .earth, parent: nil, samples: [
        .init(epoch: 0, position: SIMD3(.nan, 0, 0)),
        .init(epoch: 2, position: SIMD3(1, 0, 0))
    ])]
    presenter.update(snapshot: scene, transfer: .inactive, context: orbitLineContext())
    #expect(presenter.ribbons.values.allSatisfy { !$0.entity.isEnabled })
}

@MainActor
@Test func orbitLineMaterialUsesBodyColorAtTwentySevenPointFivePercentOpacity() throws {
    let presenter = try RealityOrbitLines()
    presenter.setVisible(true)
    presenter.update(snapshot: orbitLineScene(), transfer: .inactive, context: orbitLineContext())
    let earth = try #require(presenter.ribbons[.earth]?.entity)
    let material = try #require(earth.model?.materials.first as? UnlitMaterial)
    let color = RealityOrbitLines.color(for: .earth)
    #expect(color.z > color.x)
    #expect(color.w == 0.275)
    #expect(material.color.tint.cgColor.alpha == 1)
    if case let .transparent(opacity) = material.blending {
        #expect(opacity.scale == 0.275)
    } else {
        Issue.record("Orbit lines must use transparent blending")
    }
    let model = try #require(earth.model)
    let mesh = try #require(model.mesh.lowLevelMesh)
    mesh.withUnsafeBytes(bufferIndex: 0) { buffer in
        // A uniform white vertex uses the material's color/opacity exactly once.
        let vertexColor = buffer.load(fromByteOffset: MemoryLayout<SIMD3<Float>>.stride, as: SIMD4<Float>.self)
        #expect(vertexColor == SIMD4(repeating: 1))
    }
}

private func orbitLineScene() -> UniverseSceneSnapshot {
    let bodies = [CelestialBodyID.earth, .mars, .moon]
    let packets = bodies.map {
        CelestialBodySnapshot(planetName: $0.rawValue, baseModelMatrix: matrix_identity_float4x4,
                               normalizedScale: 1, framingRadius: 1, surfaceRadius: 1,
                               worldPosition: SIMD3(1, 0, 10))
    }
    let orbits = bodies.map {
        CelestialOrbitSnapshot(body: $0, parent: nil, samples: [
            .init(epoch: 0, position: SIMD3(0, 0, 10)),
            .init(epoch: 2, position: SIMD3(2, 0, 10))
        ])
    }
    return UniverseSceneSnapshot(frameID: 0, simulationTime: 1, planets: packets, orbits: orbits)
}

private func orbitLineContext() -> RealityProceduralSceneContent.RenderContext {
    RealityProceduralSceneContent.RenderContext(sceneOrigin: .zero, cameraPosition: .zero,
                                                cameraUp: SIMD3(0, 1, 0), renderViewMatrix: matrix_identity_float4x4,
                                                verticalFieldOfView: CameraFit.verticalFieldOfView,
                                                viewportHeight: 844)
}

@Test func orbitLineWidthStaysOnePointAtBothEndsOfDeepSegments() {
    let viewportHeight: Float = 844
    let fov = CameraFit.verticalFieldOfView
    let unitHalfWidth = RealityRibbon.halfWidth(cameraSpaceDepth: 1, verticalFieldOfView: fov,
                                               viewportHeight: viewportHeight, lineWidth: 1)
    let view = float4x4.lookAt(eye: SIMD3(7, 8, 9), target: SIMD3(7, 8, 10), upVector: SIMD3(0, 1, 0))
    let inverseView = simd_inverse(view)
    let localStart = inverseView * SIMD4<Float>(0, 0, 0.01, 1)
    let localEnd = inverseView * SIMD4<Float>(100, 200, 10_000, 1)
    let corners = OrbitLineGeometry.positions(start: SIMD3(localStart.x, localStart.y, localStart.z),
                                              end: SIMD3(localEnd.x, localEnd.y, localEnd.z),
                                              view: view, inverseView: inverseView,
                                              halfWidthAtUnitDepth: unitHalfWidth)
    #expect(corners.count == 4)
    guard corners.count == 4 else { return }
    let projected = corners.map { point -> SIMD2<Float> in
        let camera = view * SIMD4(point, 1)
        return SIMD2(camera.x, camera.y) / camera.z * viewportHeight / (2 * tan(fov / 2))
    }
    #expect(abs(simd_distance(projected[0], projected[1]) - 1) < 0.05)
    #expect(abs(simd_distance(projected[2], projected[3]) - 1) < 0.001)
}

@Test func orbitLineGeometryClipsCameraCrossingsAndRejectsHiddenSegments() {
    let corners = OrbitLineGeometry.positions(start: SIMD3(0, 0, -1), end: SIMD3(1, 0, 1),
                                              view: matrix_identity_float4x4,
                                              inverseView: matrix_identity_float4x4,
                                              halfWidthAtUnitDepth: 0.001)
    #expect(corners.count == 4)
    #expect(corners.allSatisfy { $0.z >= CameraFit.minimumNearPlane && simd_length($0).isFinite })
    let hidden = OrbitLineGeometry.positions(start: SIMD3(0, 0, -2), end: SIMD3(1, 0, -1),
                                             view: matrix_identity_float4x4,
                                             inverseView: matrix_identity_float4x4,
                                             halfWidthAtUnitDepth: 0.001)
    #expect(hidden.isEmpty)
}
