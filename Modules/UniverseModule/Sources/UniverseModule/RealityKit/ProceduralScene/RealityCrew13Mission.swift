import RealityKit
import UIKit

/// Reusable mission geometry. Per-frame work only changes poses, plume visibility,
/// and the nose-cone hinge; no meshes or entities are allocated during playback.
@MainActor
final class RealityCrew13Mission {
    let root = Entity()
    let dragon = Entity()
    let firstStage = Entity()
    let secondStage = Entity()
    let station = Entity()
    let noseCone = Entity()
    private let firstStagePlume = Entity()
    private let secondStagePlume = Entity()

    init() {
        root.name = "Crew13"
        dragon.name = "CrewDragon"
        firstStage.name = "Falcon9FirstStage"
        secondStage.name = "Falcon9SecondStage"
        station.name = "ISS"
        noseCone.name = "DragonNoseCone"
        buildDragon()
        buildRocket()
        buildStation()
        for entity in [dragon, firstStage, secondStage, station] { root.addChild(entity) }
        root.isEnabled = false
    }

    func update(state: NavigationRouteRenderState, sceneOrigin: SIMD3<Float>) {
        guard let profile = state.route?.crew13Profile, let flight = state.crew13Flight else {
            root.isEnabled = false
            return
        }
        root.isEnabled = true
        apply(flight.dragon, to: dragon, scale: profile.vehicleScale, sceneOrigin: sceneOrigin)
        apply(flight.firstStage, to: firstStage, scale: profile.vehicleScale, sceneOrigin: sceneOrigin)
        apply(flight.secondStage, to: secondStage, scale: profile.vehicleScale, sceneOrigin: sceneOrigin)
        apply(flight.station, to: station, scale: profile.stationScale, sceneOrigin: sceneOrigin)
        firstStage.isEnabled = flight.firstStageVisible
        secondStage.isEnabled = flight.secondStageVisible
        noseCone.orientation = simd_quatf(angle: -flight.noseConeOpen * .pi * 0.7, axis: SIMD3(0, 0, 1))
        updatePlume(firstStagePlume, strength: flight.firstStageThrust, time: state.elapsedTime)
        updatePlume(secondStagePlume, strength: flight.secondStageThrust, time: state.elapsedTime)
    }

    private func apply(_ pose: MissionVehiclePose, to entity: Entity,
                       scale: Float, sceneOrigin: SIMD3<Float>) {
        entity.position = pose.position - sceneOrigin
        entity.orientation = pose.orientation
        entity.scale = SIMD3(repeating: scale)
    }

    private func updatePlume(_ entity: Entity, strength: Float, time: Double) {
        entity.isEnabled = strength > 0
        entity.scale.y = strength * (1 + 0.08 * sin(Float(time) * 37))
    }

    private func buildDragon() {
        let white = SimpleMaterial(color: UIColor(white: 0.91, alpha: 1), roughness: 0.4, isMetallic: false)
        let black = SimpleMaterial(color: UIColor(white: 0.06, alpha: 1), roughness: 0.5, isMetallic: false)
        let metal = SimpleMaterial(color: .lightGray, roughness: 0.3, isMetallic: true)
        Self.part(in: dragon, mesh: .generateCylinder(height: 0.32, radius: 0.145), material: white,
                  position: SIMD3(0, -0.20, 0))
        Self.part(in: dragon, mesh: .generateCylinder(height: 0.20, radius: 0.16), material: white,
                  position: SIMD3(0, 0.06, 0))
        Self.part(in: dragon, mesh: .generateCone(height: 0.26, radius: 0.16), material: white,
                  position: SIMD3(0, 0.29, 0))
        // Dark trunk panels, capsule windows, and the heat-shield rim distinguish Dragon.
        Self.part(in: dragon, mesh: .generateCylinder(height: 0.035, radius: 0.165), material: black,
                  position: SIMD3(0, -0.045, 0))
        for side: Float in [-1, 1] {
            Self.part(in: dragon, mesh: .generateBox(size: SIMD3(0.015, 0.26, 0.15)), material: black,
                      position: SIMD3(side * 0.145, -0.20, 0))
            Self.part(in: dragon, mesh: .generateBox(size: SIMD3(0.075, 0.045, 0.012), cornerRadius: 0.009),
                      material: black, position: SIMD3(side * 0.073, 0.155, 0.123))
            Self.part(in: dragon, mesh: .generateBox(size: SIMD3(0.028, 0.29, 0.1)), material: white,
                      position: SIMD3(side * 0.16, -0.21, -0.06))
        }
        Self.part(in: dragon, mesh: .generateCylinder(height: 0.08, radius: 0.06), material: metal,
                  position: SIMD3(0, 0.46, 0))
        Self.dockingPort(in: dragon, offset: Crew13RouteProfile.dragonDockingOffset,
                         material: metal, name: "DragonDockingPort")
        noseCone.position = SIMD3(-0.08, 0.42, 0)
        let cap = Self.part(in: noseCone, mesh: .generateSphere(radius: 0.12), material: white,
                            position: SIMD3(0.08, 0.04, 0))
        cap.scale = SIMD3(1, 0.55, 1)
        dragon.addChild(noseCone)
    }

    private func buildRocket() {
        let white = SimpleMaterial(color: UIColor(white: 0.88, alpha: 1), roughness: 0.5, isMetallic: false)
        let dark = SimpleMaterial(color: UIColor(white: 0.10, alpha: 1), roughness: 0.5, isMetallic: true)
        Self.part(in: firstStage, mesh: .generateCylinder(height: 3.1, radius: 0.145), material: white)
        Self.part(in: firstStage, mesh: .generateCylinder(height: 0.35, radius: 0.147), material: dark,
                  position: SIMD3(0, 1.37, 0))
        Self.part(in: secondStage, mesh: .generateCylinder(height: 1.5, radius: 0.145), material: white)
        Self.part(in: secondStage, mesh: .generateCone(height: 0.16, radius: 0.085), material: dark,
                  position: SIMD3(0, -0.80, 0))
        for index in 0..<4 {
            let angle = Float(index) * .pi / 2
            let fin = Self.part(in: firstStage, mesh: .generateBox(size: SIMD3(0.12, 0.08, 0.035)),
                                material: dark, position: SIMD3(sin(angle) * 0.18, 1.22, cos(angle) * 0.18))
            fin.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            let leg = Self.part(in: firstStage, mesh: .generateBox(size: SIMD3(0.045, 0.55, 0.035)),
                                material: dark, position: SIMD3(sin(angle) * 0.145, -1.13, cos(angle) * 0.145))
            leg.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
        }
        for index in 0..<9 {
            let angle = Float(index) * 2 * .pi / 8
            let offset: Float = index == 8 ? 0 : 0.085
            Self.part(in: firstStage, mesh: .generateCone(height: 0.1, radius: 0.033), material: dark,
                      position: SIMD3(cos(angle) * offset, -1.57, sin(angle) * offset))
        }
        Self.buildPlume(in: firstStagePlume, length: 1.4, radius: 0.13)
        Self.buildPlume(in: secondStagePlume, length: 0.85, radius: 0.075)
        firstStagePlume.position.y = -1.6
        secondStagePlume.position.y = -0.85
        firstStage.addChild(firstStagePlume)
        secondStage.addChild(secondStagePlume)
    }

    private func buildStation() {
        let white = SimpleMaterial(color: UIColor(white: 0.83, alpha: 1), roughness: 0.45, isMetallic: true)
        let metal = SimpleMaterial(color: UIColor(white: 0.53, alpha: 1), roughness: 0.35, isMetallic: true)
        let solar = SimpleMaterial(color: UIColor(red: 0.16, green: 0.25, blue: 0.43, alpha: 1),
                                   roughness: 0.45, isMetallic: true)
        let gold = SimpleMaterial(color: UIColor(red: 0.64, green: 0.40, blue: 0.14, alpha: 1),
                                  roughness: 0.55, isMetallic: true)
        for height: Float in [-0.40, -0.12, 0.18, 0.42] {
            Self.part(in: station, mesh: .generateCylinder(height: 0.25, radius: 0.13), material: white,
                      position: SIMD3(0, height, 0))
        }
        for side: Float in [-1, 1] {
            let module = Self.part(in: station, mesh: .generateCylinder(height: 0.4, radius: 0.12),
                                   material: white, position: SIMD3(side * 0.26, 0.14, 0))
            module.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
        }
        Self.part(in: station, mesh: .generateCylinder(height: 0.13, radius: 0.075), material: white,
                  position: SIMD3(0, 0.585, 0))
        Self.dockingPort(in: station, offset: Crew13RouteProfile.stationDockingOffset,
                         material: metal, name: "ISSDockingPort")
        Self.part(in: station, mesh: .generateBox(size: SIMD3(4.5, 0.055, 0.055)), material: metal,
                  position: SIMD3(0, -0.15, 0.15))
        for side: Float in [-1, 1] {
            for span: Float in [1.05, 2.0] {
                Self.part(in: station, mesh: .generateBox(size: SIMD3(0.72, 0.04, 2.0)), material: gold,
                          position: SIMD3(side * span, -0.15, 0.15))
                for wing: Float in [-1, 1] {
                    Self.part(in: station, mesh: .generateBox(size: SIMD3(0.68, 0.045, 0.88)), material: solar,
                              position: SIMD3(side * span, -0.12, 0.15 + wing * 0.53))
                    for line in 0..<5 {
                        Self.part(in: station, mesh: .generateBox(size: SIMD3(0.008, 0.007, 0.88)),
                                  material: metal,
                                  position: SIMD3(side * span + Float(line - 2) * 0.13, -0.093, 0.15 + wing * 0.53))
                    }
                }
            }
            Self.part(in: station, mesh: .generateBox(size: SIMD3(0.65, 0.035, 0.4)), material: white,
                      position: SIMD3(side * 0.65, -0.15, -0.4))
        }
    }

    private static func buildPlume(in parent: Entity, length: Float, radius: Float) {
        var glow = UnlitMaterial(color: UIColor(red: 0.6, green: 0.75, blue: 1, alpha: 1))
        glow.blending = .transparent(opacity: .init(scale: 0.4))
        let plume = part(in: parent, mesh: .generateCone(height: length, radius: radius), material: glow,
                         position: SIMD3(0, -length / 2, 0))
        plume.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        let core = part(in: parent, mesh: .generateSphere(radius: radius * 0.5),
                        material: UnlitMaterial(color: UIColor(red: 1, green: 0.88, blue: 0.6, alpha: 1)),
                        position: SIMD3(0, -length * 0.18, 0))
        core.scale = SIMD3(1, 4, 1)
    }

    private static func dockingPort(in parent: Entity, offset: SIMD3<Float>,
                                    material: any Material, name: String) {
        // The named entity is the contact plane; mesh thickness extends toward its body.
        let port = Entity()
        port.name = name
        port.position = offset
        part(in: port, mesh: .generateCylinder(height: 0.04, radius: 0.075), material: material,
             position: SIMD3(0, -0.02, 0))
        parent.addChild(port)
    }

    @discardableResult
    private static func part(in parent: Entity, mesh: MeshResource, material: any Material,
                             position: SIMD3<Float> = .zero) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        parent.addChild(entity)
        return entity
    }
}
