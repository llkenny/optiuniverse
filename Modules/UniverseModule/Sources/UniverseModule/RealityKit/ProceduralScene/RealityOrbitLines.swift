import RealityKit
import simd

@MainActor
final class RealityOrbitLines {
    let root = Entity()
    private(set) var ribbons: [CelestialBodyID: RealityRibbon] = [:]

    init() throws {
        root.name = "CelestialOrbitLines"
        for body in CelestialBodyID.allCases where body != .sun {
            let ribbon = try RealityRibbon(maximumSegmentCount: 257, uniformColor: true)
            ribbon.entity.name = "\(body.rawValue).OrbitLine"
            ribbons[body] = ribbon
            root.addChild(ribbon.entity)
        }
    }

    func hide() {
        for ribbon in ribbons.values { ribbon.hide() }
    }

    func update(snapshot: UniverseSceneSnapshot?, transfer: TransferOrbitRenderState,
                context: RealityProceduralSceneContent.RenderContext) {
        // Hide first: missing/invalid packets and failed ribbon updates must never
        // leave a previous epoch's trajectory visible.
        hide()
        guard let snapshot else { return }
        let suppressed = Self.suppressedBodies(for: transfer)
        for orbit in snapshot.orbits where !suppressed.contains(orbit.body) {
            guard let ribbon = ribbons[orbit.body] else { continue }
            ribbon.update(points: orbit.renderPoints(in: snapshot, relativeTo: context.sceneOrigin),
                          sceneOrigin: .zero,
                          cameraPosition: context.cameraPosition,
                          cameraUp: context.cameraUp,
                          renderViewMatrix: context.renderViewMatrix,
                          verticalFieldOfView: context.verticalFieldOfView,
                          viewportHeight: context.viewportHeight,
                          color: Self.color(for: orbit.body),
                          lineWidth: 1)
        }
    }

    private static func suppressedBodies(for transfer: TransferOrbitRenderState) -> Set<CelestialBodyID> {
        var suppressed: Set<CelestialBodyID> = []
        let solution = transfer.transferOrbit
        if !(solution?.preciseEarthOrbitPoints ?? transfer.preciseEarthOrbitPoints).isEmpty
            || !transfer.earthOrbitPoints.isEmpty {
            suppressed.insert(.earth)
        }
        if !(solution?.preciseDestinationOrbitPoints ?? transfer.preciseDestinationOrbitPoints).isEmpty
            || !transfer.destinationOrbitPoints.isEmpty,
           let name = solution?.destinationName ?? transfer.destinationName,
           let destination = CelestialBodyID(rawValue: name) {
            suppressed.insert(destination)
        }
        return suppressed
    }

    nonisolated static func color(for body: CelestialBodyID) -> SIMD4<Float> {
        let rgb: SIMD3<Float>
        switch body {
        case .mercury: rgb = SIMD3(0.62, 0.59, 0.55)
        case .venus: rgb = SIMD3(0.94, 0.83, 0.62)
        case .earth: rgb = SIMD3(0.26, 0.55, 1)
        case .moon: rgb = SIMD3(0.78, 0.80, 0.84)
        case .mars: rgb = SIMD3(0.86, 0.35, 0.20)
        case .jupiter: rgb = SIMD3(0.80, 0.64, 0.46)
        case .sun, .saturn: rgb = SIMD3(0.91, 0.76, 0.43)
        case .uranus: rgb = SIMD3(0.40, 0.84, 0.88)
        case .neptune: rgb = SIMD3(0.24, 0.36, 0.90)
        case .pluto: rgb = SIMD3(0.64, 0.48, 0.39)
        }
        return SIMD4(rgb, 0.55)
    }
}
