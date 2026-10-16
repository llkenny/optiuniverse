import RealityKit
import UIKit

/// All meshes/materials are built once. Playback only changes transforms and visibility.
@MainActor
final class RealityVoyagerMission {
    let root = Entity()
    let probe = Entity()
    let rocket = Entity()
    let centaur = Entity()
    private let boosters = Entity()
    private let fairing = Entity()
    private let plume = Entity()
    private let upperPlume = Entity()

    init() {
        root.name = "Voyager1"
        probe.name = "VoyagerProbe"
        rocket.name = "TitanIIIE"
        centaur.name = "Centaur"
        buildProbe()
        buildRocket()
        for entity in [probe, rocket, centaur] { root.addChild(entity) }
        root.isEnabled = false
    }

    func update(state: NavigationRouteRenderState, sceneOrigin: SIMD3<Double>) {
        guard let flight = state.voyagerFlight else { root.isEnabled = false; return }
        root.isEnabled = true
        apply(flight.probe, entity: probe, scale: flight.vehicleScale, origin: sceneOrigin)
        apply(flight.rocket, entity: rocket, scale: flight.rocketScale, origin: sceneOrigin)
        apply(flight.centaur, entity: centaur, scale: flight.rocketScale, origin: sceneOrigin)
        let time = state.elapsedTime
        probe.isEnabled = time >= 12
        rocket.isEnabled = time < 13
        centaur.isEnabled = time < 16
        fairing.isEnabled = time < 12
        plume.isEnabled = time < 8
        upperPlume.isEnabled = time >= 8 && time < 14
        let separation = VoyagerRouteProfile.smooth((time - 8) / 3)
        for (index, booster) in boosters.children.enumerated() {
            let side: Float = index == 0 ? -1 : 1
            booster.position.x = side * (0.47 + separation * 2)
            booster.position.y = -separation * 1.5
        }
        let flicker = 1 + 0.08 * sin(Float(time) * 37)
        plume.scale.y = flicker
        upperPlume.scale.y = flicker
    }

    private func apply(_ pose: MissionVehiclePose, entity: Entity, scale: Float, origin: SIMD3<Double>) {
        entity.position = EphemerisCoordinates.renderPosition(pose.precisePosition, relativeTo: origin)
        entity.orientation = pose.orientation
        entity.scale = SIMD3(repeating: scale)
    }

    private func buildProbe() {
        let white = SimpleMaterial(color: .init(white: 0.92, alpha: 1), roughness: 0.45, isMetallic: false)
        let metal = SimpleMaterial(color: .lightGray, roughness: 0.4, isMetallic: true)
        let dark = SimpleMaterial(color: .init(white: 0.13, alpha: 1), roughness: 0.7, isMetallic: false)
        let gold = SimpleMaterial(color: .init(red: 0.85, green: 0.6, blue: 0.19, alpha: 1),
                                  roughness: 0.35, isMetallic: true)
        part(probe, .generateCylinder(height: 0.32, radius: 0.3), dark, SIMD3(0, -0.28, 0), name: "InstrumentBus")
        // An open paraboloid with a visible rim, rather than a closed cone.
        let dish = ModelEntity(mesh: Self.dishMesh(), materials: [white])
        dish.name = "HighGainAntenna"
        probe.addChild(dish)
        for angleIndex in 0..<3 {
            let angle = Float(angleIndex) * 2 * .pi / 3
            strut(probe, from: SIMD3(cos(angle) * 0.7, 0.12, sin(angle) * 0.7),
                  to: SIMD3(0, 0.8, 0), radius: 0.014, material: metal)
        }
        part(probe, .generateSphere(radius: 0.07), metal, SIMD3(0, 0.8, 0), name: "AntennaFeed")
        strut(probe, from: SIMD3(0.2, -0.3, 0), to: SIMD3(1.6, -0.7, 0), radius: 0.025, material: metal)
        for index in 0..<3 {
            let rtg = part(probe, .generateCylinder(height: 0.3, radius: 0.13), dark,
                           SIMD3(1.2 + Float(index) * 0.3, -0.6, 0), name: "RTG\(index)")
            rtg.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
            for fin in 0..<4 {
                part(rtg, .generateBox(size: SIMD3(0.025, 0.31, 0.34)), metal)
                    .orientation = simd_quatf(angle: Float(fin) * .pi / 4, axis: SIMD3(0, 1, 0))
            }
        }
        strut(probe, from: SIMD3(-0.2, -0.3, 0), to: SIMD3(-2.4, -0.5, 0), radius: 0.015, material: metal)
        part(probe, .generateBox(size: SIMD3(0.23, 0.2, 0.28)), dark,
             SIMD3(-1.1, -0.45, 0), name: "ScienceScanPlatform")
        part(probe, .generateSphere(radius: 0.07), dark, SIMD3(-2.4, -0.5, 0), name: "Magnetometer")
        let record = part(probe, .generateCylinder(height: 0.014, radius: 0.13), gold,
                          SIMD3(0, -0.28, 0.3), name: "GoldenRecord")
        record.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        for side: Float in [-1, 1] {
            strut(probe, from: SIMD3(0, -0.3, 0), to: SIMD3(side * 1.8, -1.3, 0.4),
                  radius: 0.008, material: metal)
        }
    }

    private func buildRocket() {
        let white = SimpleMaterial(color: .init(white: 0.9, alpha: 1), roughness: 0.55, isMetallic: false)
        let dark = SimpleMaterial(color: .init(white: 0.16, alpha: 1), roughness: 0.5, isMetallic: true)
        let metal = SimpleMaterial(color: .lightGray, roughness: 0.35, isMetallic: true)
        part(rocket, .generateCylinder(height: 3.1, radius: 0.3), metal)
        part(rocket, .generateCylinder(height: 0.4, radius: 0.305), dark, SIMD3(0, 1.25, 0))
        for side: Float in [-1, 1] {
            let booster = Entity()
            booster.position.x = side * 0.47
            part(booster, .generateCylinder(height: 3.0, radius: 0.19), white)
            part(booster, .generateCone(height: 0.5, radius: 0.19), white, SIMD3(0, 1.75, 0))
            boosters.addChild(booster)
        }
        rocket.addChild(boosters)
        part(centaur, .generateCylinder(height: 1.05, radius: 0.3), metal, SIMD3(0, -0.3, 0))
        part(fairing, .generateCylinder(height: 0.8, radius: 0.36), white, SIMD3(0, 0.55, 0))
        part(fairing, .generateCone(height: 0.55, radius: 0.36), white, SIMD3(0, 1.225, 0))
        centaur.addChild(fairing)
        buildPlume(plume, length: 2, radius: 0.32)
        plume.position.y = -1.6
        rocket.addChild(plume)
        buildPlume(upperPlume, length: 1, radius: 0.18)
        upperPlume.position.y = -0.85
        centaur.addChild(upperPlume)
    }

    private func buildPlume(_ parent: Entity, length: Float, radius: Float) {
        let material = UnlitMaterial(color: .init(red: 1, green: 0.63, blue: 0.22, alpha: 1))
        let flame = part(parent, .generateCone(height: length, radius: radius), material, SIMD3(0, -length / 2, 0))
        flame.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
    }

    private func strut(_ parent: Entity, from: SIMD3<Float>, to endpoint: SIMD3<Float>, radius: Float,
                       material: any Material) {
        let axis = endpoint - from
        let entity = part(parent, .generateCylinder(height: length(axis), radius: radius),
                          material, (from + endpoint) / 2)
        entity.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: normalize(axis))
    }

    @discardableResult
    private func part(_ parent: Entity, _ mesh: MeshResource, _ material: any Material,
                      _ position: SIMD3<Float> = .zero, name: String = "") -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        entity.position = position
        parent.addChild(entity)
        return entity
    }

    private static func dishMesh() -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let rings = 12
        let segments = 48
        for ring in 0...rings {
            let radius = Float(ring) / Float(rings)
            for segment in 0...segments {
                let angle = Float(segment) * 2 * .pi / Float(segments)
                let xValue = radius * cos(angle)
                let zValue = radius * sin(angle)
                positions.append(SIMD3(xValue, 0.22 * radius * radius, zValue))
                normals.append(normalize(SIMD3(-0.44 * xValue, 1, -0.44 * zValue)))
            }
        }
        for ring in 0..<rings {
            for segment in 0..<segments {
                let lower = UInt32(ring * (segments + 1) + segment)
                let upper = lower + UInt32(segments + 1)
                // Both sides remain visible when the camera circles the antenna.
                indices += [lower, upper, lower + 1, lower + 1, upper, upper + 1,
                            lower + 1, upper, lower, upper + 1, upper, lower + 1]
            }
        }
        var descriptor = MeshDescriptor(name: "VoyagerParabolicDish")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        // Procedurally generated bounded indices; a fallback preserves scene preparation.
        return (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: 1)
    }
}
