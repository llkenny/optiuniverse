import CoreImage
import RealityKit
import UIKit

// Procedural presenters share the same packed vertex format and atomic publication helpers.
// swiftlint:disable file_length

@MainActor
final class RealityProceduralSceneContent {
    nonisolated private static let environmentRadius: Float = 9_000

    let environmentEntity: ModelEntity
    let starField: RealityStarField
    let transferEarthOrbit: RealityRibbon
    let transferDestinationOrbit: RealityRibbon
    let transferPath: RealityRibbon
    let navigationPath: RealityRibbon
    let navigationMarker: Entity

    private static let transferSampleCount = 256
    static let navigationRouteColor = SIMD4<Float>(0.2, 0.82, 1, 0.45)

    static func prepare() async throws -> RealityProceduralSceneContent {
        let environmentEntity = try await makeEnvironmentEntity()
        return try RealityProceduralSceneContent(environmentEntity: environmentEntity)
    }

    private init(environmentEntity: ModelEntity) throws {
        self.environmentEntity = environmentEntity
        starField = try RealityStarField()
        transferEarthOrbit = try RealityRibbon(maximumSegmentCount: 512)
        transferDestinationOrbit = try RealityRibbon(maximumSegmentCount: 512)
        transferPath = try RealityRibbon(maximumSegmentCount: 512)
        navigationPath = try RealityRibbon(maximumSegmentCount: 2_048)
        navigationMarker = Self.makeNavigationMarker()
    }

    func update(frameState: UniverseFrameState) {
        let camera = frameState.cameraSnapshot
        let cameraMatrix = simd_inverse(camera.renderViewMatrix)
        let cameraPosition = SIMD3<Float>(cameraMatrix.columns.3.x,
                                          cameraMatrix.columns.3.y,
                                          cameraMatrix.columns.3.z)
        let cameraRight = normalizeOrFallback(
            SIMD3<Float>(cameraMatrix.columns.0.x,
                         cameraMatrix.columns.0.y,
                         cameraMatrix.columns.0.z),
            fallback: SIMD3<Float>(1, 0, 0)
        )
        let cameraUp = normalizeOrFallback(
            SIMD3<Float>(cameraMatrix.columns.1.x,
                         cameraMatrix.columns.1.y,
                         cameraMatrix.columns.1.z),
            fallback: SIMD3<Float>(0, 1, 0)
        )

        environmentEntity.position = cameraPosition
        environmentEntity.scale = SIMD3<Float>(repeating: Self.environmentScale(
            farPlane: camera.dependencies.projection.farPlane
        ))
        starField.update(sceneOrigin: camera.sceneOrigin,
                         cameraPosition: cameraPosition,
                         cameraRight: cameraRight,
                         cameraUp: cameraUp,
                         simulationTime: frameState.simulationTime)
        updateTransfer(state: frameState.routes.transfer,
                       sceneOrigin: camera.sceneOrigin,
                       cameraPosition: cameraPosition,
                       cameraUp: cameraUp,
                       renderViewMatrix: camera.renderViewMatrix,
                       verticalFieldOfView: camera.dependencies.projection.verticalFieldOfView,
                       viewportHeight: Float(camera.viewportSize.height))
        updateNavigation(state: frameState.routes.navigation,
                         sceneOrigin: camera.sceneOrigin,
                         cameraPosition: cameraPosition,
                         cameraUp: cameraUp,
                         renderViewMatrix: camera.renderViewMatrix,
                         verticalFieldOfView: camera.dependencies.projection.verticalFieldOfView,
                         viewportHeight: Float(camera.viewportSize.height),
                         elapsedTime: frameState.routes.navigation.elapsedTime)
    }

    private func updateTransfer(state: TransferOrbitRenderState,
                                sceneOrigin: SIMD3<Float>,
                                cameraPosition: SIMD3<Float>,
                                cameraUp: SIMD3<Float>,
                                renderViewMatrix: float4x4,
                                verticalFieldOfView: Float,
                                viewportHeight: Float) {
        guard let orbit = state.transferOrbit else {
            transferEarthOrbit.hide()
            transferDestinationOrbit.hide()
            transferPath.hide()
            return
        }

        transferEarthOrbit.update(
            points: Self.circlePoints(center: orbit.sunPosition,
                                      radius: orbit.earthOrbitRadius),
            sceneOrigin: sceneOrigin,
            cameraPosition: cameraPosition,
            cameraUp: cameraUp,
            renderViewMatrix: renderViewMatrix,
            verticalFieldOfView: verticalFieldOfView,
            viewportHeight: viewportHeight,
            color: SIMD4<Float>(0.26, 0.55, 1, 0.72),
            dashFrequency: 72,
            dashDuty: 0.48,
            lineWidth: 1.75
        )
        transferDestinationOrbit.update(
            points: Self.circlePoints(center: orbit.sunPosition,
                                      radius: orbit.destinationOrbitRadius),
            sceneOrigin: sceneOrigin,
            cameraPosition: cameraPosition,
            cameraUp: cameraUp,
            renderViewMatrix: renderViewMatrix,
            verticalFieldOfView: verticalFieldOfView,
            viewportHeight: viewportHeight,
            color: SIMD4<Float>(1, 0.62, 0.22, 0.72),
            dashFrequency: 92,
            dashDuty: 0.48,
            lineWidth: 1.75
        )
        transferPath.update(points: orbit.points,
                            sceneOrigin: sceneOrigin,
                            cameraPosition: cameraPosition,
                            cameraUp: cameraUp,
                            renderViewMatrix: renderViewMatrix,
                            verticalFieldOfView: verticalFieldOfView,
                            viewportHeight: viewportHeight,
                            color: SIMD4<Float>(0.2, 0.82, 1, 1),
                            lineWidth: 2.5)
    }

    private func updateNavigation(state: NavigationRouteRenderState,
                                  sceneOrigin: SIMD3<Float>,
                                  cameraPosition: SIMD3<Float>,
                                  cameraUp: SIMD3<Float>,
                                  renderViewMatrix: float4x4,
                                  verticalFieldOfView: Float,
                                  viewportHeight: Float,
                                  elapsedTime: TimeInterval) {
        guard let route = state.route,
              let markerPosition = route.point(at: state.progress) else {
            navigationPath.hide()
            navigationMarker.isEnabled = false
            return
        }

        let visiblePoints = Self.navigationRenderPoints(route: route,
                                                        progress: state.progress)
        if visiblePoints.count >= 2 {
            navigationPath.update(points: visiblePoints,
                                  sceneOrigin: sceneOrigin,
                                  cameraPosition: cameraPosition,
                                  cameraUp: cameraUp,
                                  renderViewMatrix: renderViewMatrix,
                                  verticalFieldOfView: verticalFieldOfView,
                                  viewportHeight: viewportHeight,
                                  color: Self.navigationRouteColor)
        } else {
            navigationPath.hide()
        }
        navigationMarker.isEnabled = true
        navigationMarker.position = markerPosition - sceneOrigin
        let cameraDistance = max(simd_distance(navigationMarker.position, cameraPosition), 0.001)
        let pulse = 1 + 0.08 * sin(Float(elapsedTime) * 6)
        navigationMarker.scale = SIMD3<Float>(repeating: cameraDistance * 0.008 * pulse)
    }

    static func navigationRenderPoints(route: NavigationRoute,
                                       progress: Float) -> [SIMD3<Float>] {
        guard ArtemisRouteProfile.isArtemisRoute(route) else {
            return route.points
        }

        let openingPhaseEnd = ArtemisRouteProfile.openingPhaseEnd(
            estimatedDuration: route.estimatedDuration
        )
        guard progress < openingPhaseEnd else {
            return route.points
        }

        let easedProgress = ArtemisRouteProfile.easedOpeningProgress(
            routeProgress: progress,
            estimatedDuration: route.estimatedDuration
        )
        return route.prefixPoints(through: max(progress, easedProgress))
    }

    static func circlePoints(center: SIMD3<Float>, radius: Float) -> [SIMD3<Float>] {
        guard radius.isFinite, radius > 0 else { return [] }
        return (0...transferSampleCount).map { index in
            let angle = Float(index) / Float(transferSampleCount) * 2 * .pi
            return center + SIMD3<Float>(radius * cos(angle), 0, -radius * sin(angle))
        }
    }

    private static func makeEnvironmentEntity() async throws -> ModelEntity {
        guard let url = UniverseModuleAssets.milkyWayEnvironmentURL(),
              let inputImage = CIImage(contentsOf: url) else {
            throw RealityProceduralScenePreparationError.missingEnvironment
        }
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(0.7, forKey: kCIInputSaturationKey)
        filter?.setValue(-0.12, forKey: kCIInputBrightnessKey)
        guard let outputImage = filter?.outputImage,
              let cgImage = CIContext(options: [.cacheIntermediates: false]).createCGImage(
                outputImage,
                from: outputImage.extent
              ) else {
            throw RealityProceduralScenePreparationError.invalidEnvironment
        }

        let texture = try await TextureResource(
            image: cgImage,
            withName: "MilkyWayEnvironment",
            options: .init(semantic: .color)
        )
        var material = UnlitMaterial(texture: texture)
        material.faceCulling = .front
        let entity = ModelEntity(mesh: .generateSphere(radius: environmentRadius),
                                 materials: [material])
        entity.name = "MilkyWayEnvironment"
        return entity
    }

    private static func makeNavigationMarker() -> Entity {
        let material = UnlitMaterial(color: UIColor(red: 0.25,
                                                    green: 0.95,
                                                    blue: 1,
                                                    alpha: 0.82),
                                     applyPostProcessToneMap: false)
        let entity = Entity()
        entity.name = "NavigationMarkerVisual"
        entity.components.set(BillboardComponent())
        let beadMesh = MeshResource.generateSphere(radius: 0.12)
        for index in 0..<24 {
            let angle = Float(index) / 24 * 2 * .pi
            let bead = ModelEntity(mesh: beadMesh, materials: [material])
            bead.position = SIMD3<Float>(cos(angle), sin(angle), 0)
            entity.addChild(bead)
        }
        entity.isEnabled = false
        return entity
    }

    nonisolated static func environmentScale(farPlane: Float) -> Float {
        guard farPlane.isFinite else { return 1 }
        // The environment is opaque and depth-writing. Keep its inward-facing surface
        // behind every transfer ribbon while leaving a small margin before the far clip.
        return max(1, farPlane * 0.98 / environmentRadius)
    }
}

enum RealityProceduralScenePreparationError: Error {
    case missingEnvironment
    case invalidEnvironment
}

@MainActor
final class RealityRibbon {
    let entity: ModelEntity
    private let mesh: LowLevelMesh
    private let maximumSegmentCount: Int
    private var currentColor: SIMD4<Float>?

    init(maximumSegmentCount: Int) throws {
        self.maximumSegmentCount = maximumSegmentCount
        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: maximumSegmentCount * 4,
            vertexAttributes: [
                .init(semantic: .position, format: .float3, offset: 0),
                .init(semantic: .color,
                      format: .float4,
                      offset: MemoryLayout<SIMD3<Float>>.stride)
            ],
            vertexLayouts: [
                .init(bufferIndex: 0,
                      bufferStride: MemoryLayout<RealityProceduralVertex>.stride)
            ],
            indexCapacity: maximumSegmentCount * 6,
            indexType: .uint32
        )
        mesh = try LowLevelMesh(descriptor: descriptor)
        var material = UnlitMaterial(color: .white, applyPostProcessToneMap: false)
        material.blending = .transparent(opacity: .init(scale: 1))
        entity = ModelEntity(mesh: try MeshResource(from: mesh),
                             materials: [material])
        entity.isEnabled = false
    }

    func hide() {
        entity.isEnabled = false
    }

    // Building a complete replacement before publishing keeps failed updates atomic.
    // swiftlint:disable:next function_body_length
    func update(points: [SIMD3<Float>],
                sceneOrigin: SIMD3<Float>,
                cameraPosition: SIMD3<Float>,
                cameraUp: SIMD3<Float>,
                renderViewMatrix: float4x4 = matrix_identity_float4x4,
                verticalFieldOfView: Float = CameraFit.verticalFieldOfView,
                viewportHeight: Float = 1,
                color: SIMD4<Float>,
                dashFrequency: Float = 0,
                dashDuty: Float = 1,
                lineWidth: Float = 1.5) {
        guard points.count >= 2,
              points.count - 1 <= maximumSegmentCount,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            return
        }
        updateMaterialIfNeeded(color: color)

        var vertices: [RealityProceduralVertex] = []
        var indices: [UInt32] = []
        var bounds = BoundingBox()
        vertices.reserveCapacity((points.count - 1) * 4)
        indices.reserveCapacity((points.count - 1) * 6)

        for index in 0..<(points.count - 1) {
            let progress = Float(index) / Float(max(points.count - 1, 1))
            if dashFrequency > 0, (progress * dashFrequency).truncatingRemainder(dividingBy: 1) > dashDuty {
                continue
            }
            let start = points[index] - sceneOrigin
            let end = points[index + 1] - sceneOrigin
            let direction = end - start
            guard simd_length_squared(direction) > 0.000_000_1 else { continue }
            let midpoint = (start + end) * 0.5
            let viewDirection = normalizeOrFallback(cameraPosition - midpoint,
                                                    fallback: cameraUp)
            let side = normalizeOrFallback(simd_cross(direction, viewDirection),
                                           fallback: cameraUp)
            let cameraSpaceMidpoint = renderViewMatrix * SIMD4<Float>(midpoint.x,
                                                                        midpoint.y,
                                                                        midpoint.z,
                                                                        1)
            let width = Self.halfWidth(cameraSpaceDepth: cameraSpaceMidpoint.z,
                                       verticalFieldOfView: verticalFieldOfView,
                                       viewportHeight: viewportHeight,
                                       lineWidth: lineWidth)
            let offset = side * width
            let pulse = 0.76 + 0.24 * sin(progress * .pi)
            let vertexColor = SIMD4<Float>(color.x * pulse,
                                           color.y * pulse,
                                           color.z * pulse,
                                           color.w)
            let baseIndex = UInt32(vertices.count)
            let positions = [start - offset, start + offset, end - offset, end + offset]
            for position in positions {
                vertices.append(RealityProceduralVertex(position: position, color: vertexColor))
                bounds.formUnion(position)
            }
            indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2,
                                       baseIndex + 2, baseIndex + 1, baseIndex + 3])
        }

        guard !vertices.isEmpty, !indices.isEmpty else { return }
        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { buffer in
            vertices.withUnsafeBytes { source in
                buffer.copyMemory(from: source)
            }
        }
        mesh.replaceUnsafeMutableIndices { buffer in
            indices.withUnsafeBytes { source in
                buffer.copyMemory(from: source)
            }
        }
        mesh.parts.replaceAll([
            .init(indexOffset: 0,
                  indexCount: indices.count,
                  topology: .triangle,
                  materialIndex: 0,
                  bounds: bounds)
        ])
        entity.isEnabled = true
    }

    nonisolated static func halfWidth(cameraSpaceDepth: Float,
                                      verticalFieldOfView: Float,
                                      viewportHeight: Float,
                                      lineWidth: Float) -> Float {
        guard cameraSpaceDepth.isFinite,
              verticalFieldOfView.isFinite,
              viewportHeight.isFinite,
              lineWidth.isFinite,
              viewportHeight > 0,
              lineWidth > 0 else {
            return 0
        }

        let depth = max(abs(cameraSpaceDepth), CameraFit.minimumNearPlane)
        return depth * tan(verticalFieldOfView / 2) * lineWidth / viewportHeight
    }

    private func updateMaterialIfNeeded(color: SIMD4<Float>) {
        guard color != currentColor else { return }
        currentColor = color
        let uiColor = UIColor(red: CGFloat(color.x),
                              green: CGFloat(color.y),
                              blue: CGFloat(color.z),
                              alpha: CGFloat(color.w))
        var material = UnlitMaterial(color: uiColor, applyPostProcessToneMap: false)
        material.blending = .transparent(opacity: .init(scale: color.w))
        guard var model = entity.components[ModelComponent.self] else { return }
        model.materials = [material]
        entity.components.set(model)
    }
}

@MainActor
final class RealityStarField {
    let entity: ModelEntity
    private let mesh: LowLevelMesh
    private let stars: [StarVertex]

    init(configuration: StarFieldConfiguration = StarFieldConfiguration()) throws {
        stars = StarFieldGenerator.makeStars(configuration: configuration)
        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: stars.count * 4,
            vertexAttributes: [
                .init(semantic: .position, format: .float3, offset: 0),
                .init(semantic: .color,
                      format: .float4,
                      offset: MemoryLayout<SIMD3<Float>>.stride)
            ],
            vertexLayouts: [
                .init(bufferIndex: 0,
                      bufferStride: MemoryLayout<RealityProceduralVertex>.stride)
            ],
            indexCapacity: stars.count * 6,
            indexType: .uint32
        )
        mesh = try LowLevelMesh(descriptor: descriptor)
        var material = UnlitMaterial(color: .white, applyPostProcessToneMap: false)
        material.blending = .transparent(opacity: .init(scale: 1))
        entity = ModelEntity(mesh: try MeshResource(from: mesh), materials: [material])
        entity.name = "ProceduralStarField"
    }

    func update(sceneOrigin: SIMD3<Float>,
                cameraPosition: SIMD3<Float>,
                cameraRight: SIMD3<Float>,
                cameraUp: SIMD3<Float>,
                simulationTime: Float) {
        guard !stars.isEmpty else { return }
        var vertices: [RealityProceduralVertex] = []
        var indices: [UInt32] = []
        var bounds = BoundingBox()
        vertices.reserveCapacity(stars.count * 4)
        indices.reserveCapacity(stars.count * 6)

        for (index, star) in stars.enumerated() {
            let position = star.position - sceneOrigin
            let distance = max(simd_distance(position, cameraPosition), 0.001)
            let halfSize = distance * star.pointSize * 0.000_08
            let right = cameraRight * halfSize
            let upward = cameraUp * halfSize
            let phase = sin(simulationTime * StarTwinkle.angularSpeed
                            + Float(index % 97) / 97 * 2 * .pi)
            let brightness = star.brightness * (StarTwinkle.base + StarTwinkle.amplitude * phase)
            let color = SIMD4<Float>(star.color * brightness, 1)
            let baseIndex = UInt32(vertices.count)
            let positions = [position - right - upward, position + right - upward,
                             position - right + upward, position + right + upward]
            for vertexPosition in positions {
                vertices.append(RealityProceduralVertex(position: vertexPosition, color: color))
                bounds.formUnion(vertexPosition)
            }
            indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2,
                                       baseIndex + 2, baseIndex + 1, baseIndex + 3])
        }

        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { buffer in
            vertices.withUnsafeBytes { source in buffer.copyMemory(from: source) }
        }
        mesh.replaceUnsafeMutableIndices { buffer in
            indices.withUnsafeBytes { source in buffer.copyMemory(from: source) }
        }
        mesh.parts.replaceAll([
            .init(indexOffset: 0,
                  indexCount: indices.count,
                  topology: .triangle,
                  materialIndex: 0,
                  bounds: bounds)
        ])
    }
}

private struct RealityProceduralVertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

private func normalizeOrFallback(_ value: SIMD3<Float>,
                                 fallback: SIMD3<Float>) -> SIMD3<Float> {
    guard simd_length_squared(value) > 0.000_000_1 else { return fallback }
    return simd_normalize(value)
}
