import RealityKit
import UIKit

/// Allocates reusable geometry once. Playback only changes transforms and effect visibility.
@MainActor
final class RealityStarshipMission {
    let root = Entity()
    private(set) var ship = Entity()
    private(set) var booster = Entity()
    private(set) var satellites: [Entity] = []
    private let shipPlume = Entity()
    private let boosterPlume = Entity()
    private let heatGlow = Entity()
    private let payloadDoor = Entity()
    private let shipSplash = Entity()
    private let boosterSplash = Entity()

    init() {
        root.name = "StarshipFlight14"
        ship.name = "Starship"
        booster.name = "SuperHeavy"
        buildVehicles()
        root.addChild(ship)
        root.addChild(booster)
        let prototype = Self.makeSatellite()
        satellites = (0..<StarshipRouteProfile.satelliteCount).map { index in
            let satellite = prototype.clone(recursive: true)
            satellite.name = "Starlink-\(index + 1)"
            root.addChild(satellite)
            return satellite
        }
        Self.buildSplash(in: shipSplash)
        Self.buildSplash(in: boosterSplash)
        root.addChild(shipSplash)
        root.addChild(boosterSplash)
        root.isEnabled = false
    }

    func update(state: NavigationRouteRenderState, sceneOrigin: SIMD3<Float>) {
        guard let profile = state.route?.starshipProfile, let flight = state.starshipFlight else {
            root.isEnabled = false
            return
        }
        root.isEnabled = true
        let size = profile.radius * 0.09
        apply(flight.ship, to: ship, size: size, sceneOrigin: sceneOrigin)
        apply(flight.booster, to: booster, size: size, sceneOrigin: sceneOrigin)
        booster.isEnabled = flight.boosterVisible
        updatePlume(shipPlume, strength: flight.shipThrust, time: state.elapsedTime)
        updatePlume(boosterPlume, strength: flight.boosterThrust, time: state.elapsedTime)
        let doorOpen = StarshipRouteProfile.smooth(Float((state.elapsedTime - 18) / 1))
            * (1 - StarshipRouteProfile.smooth(Float((state.elapsedTime - 28.4) / 1.6)))
        payloadDoor.position.y = doorOpen * 0.17
        heatGlow.isEnabled = flight.reentryGlow > 0.01
        heatGlow.scale = SIMD3(repeating: 1 + flight.reentryGlow * 0.12)
        heatGlow.components.set(OpacityComponent(opacity: flight.reentryGlow))
        for (index, satellite) in satellites.enumerated() {
            satellite.isEnabled = index < flight.satellites.count
            if index < flight.satellites.count {
                apply(flight.satellites[index], to: satellite, size: size * 0.24, sceneOrigin: sceneOrigin)
            }
        }
        updateSplash(shipSplash, pose: flight.ship, center: profile.center, radius: profile.radius,
                     time: state.elapsedTime - 59.7, sceneOrigin: sceneOrigin)
        updateSplash(boosterSplash, pose: flight.booster, center: profile.center, radius: profile.radius,
                     time: state.elapsedTime - 15.7, sceneOrigin: sceneOrigin)
    }

    private func apply(_ pose: MissionVehiclePose, to entity: Entity, size: Float, sceneOrigin: SIMD3<Float>) {
        entity.position = pose.position - sceneOrigin
        entity.orientation = pose.orientation
        entity.scale = SIMD3(repeating: size)
    }

    private func updatePlume(_ plume: Entity, strength: Float, time: Double) {
        plume.isEnabled = strength > 0
        plume.scale = SIMD3<Float>(1, strength * (1 + 0.09 * sin(Float(time) * 37)), 1)
    }

    private func updateSplash(_ splash: Entity, pose: MissionVehiclePose, center: SIMD3<Float>, radius: Float,
                              time: Double, sceneOrigin: SIMD3<Float>) {
        splash.isEnabled = time >= 0 && time < 1.3
        guard splash.isEnabled else { return }
        let radial = normalize(pose.position - center)
        splash.position = center + radial * radius * 1.004 - sceneOrigin
        splash.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: radial)
        splash.scale = SIMD3(repeating: radius * (0.035 + Float(time) * 0.045))
    }

    private func buildVehicles() {
        let steel = SimpleMaterial(color: UIColor(white: 0.72, alpha: 1), roughness: 0.28, isMetallic: true)
        let dark = SimpleMaterial(color: UIColor(white: 0.055, alpha: 1), roughness: 0.8, isMetallic: false)
        let fin = SimpleMaterial(color: UIColor(white: 0.22, alpha: 1), roughness: 0.45, isMetallic: true)
        Self.part(in: ship, mesh: .generateCylinder(height: 0.72, radius: 0.095), material: steel)
        // A tapered nose and a dark windward half distinguish Ship from its booster.
        Self.part(in: ship, mesh: .generateCone(height: 0.3, radius: 0.095), material: steel,
                  position: SIMD3(0, 0.51, 0))
        Self.part(in: ship, mesh: .generateBox(size: SIMD3(0.135, 0.70, 0.026), cornerRadius: 0.012),
                  material: dark, position: SIMD3(0, 0, 0.076))
        Self.part(in: ship, mesh: .generateBox(size: SIMD3(0.12, 0.16, 0.014)), material: dark,
                  position: SIMD3(0, 0.16, -0.092))
        Self.part(in: payloadDoor, mesh: .generateBox(size: SIMD3(0.125, 0.16, 0.012)), material: steel,
                  position: SIMD3(0, 0.16, -0.103))
        ship.addChild(payloadDoor)
        for side: Float in [-1, 1] {
            for height: Float in [-0.25, 0.33] {
                let flap = Self.part(in: ship, mesh: .generateBox(size: SIMD3(0.16, 0.19, 0.018), cornerRadius: 0.008),
                                     material: dark, position: SIMD3(side * 0.14, height, 0.02))
                flap.orientation = simd_quatf(angle: side * 0.3, axis: SIMD3(0, 0, 1))
            }
        }
        Self.part(in: booster, mesh: .generateCylinder(height: 1.32, radius: 0.095), material: steel)
        for index in 0..<4 {
            let angle = Float(index) * .pi / 2
            let grid = Entity()
            grid.position = SIMD3(sin(angle) * 0.13, 0.49, cos(angle) * 0.13)
            grid.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            for line in -2...2 {
                Self.part(in: grid, mesh: .generateBox(size: SIMD3(0.009, 0.13, 0.018)), material: fin,
                          position: SIMD3(Float(line) * 0.028, 0, 0))
                Self.part(in: grid, mesh: .generateBox(size: SIMD3(0.13, 0.009, 0.018)), material: fin,
                          position: SIMD3(0, Float(line) * 0.028, 0))
            }
            booster.addChild(grid)
        }
        for (vehicle, height, count) in [(ship, Float(-0.39), 6), (booster, Float(-0.68), 12)] {
            for index in 0..<count {
                let angle = Float(index) * 2 * .pi / Float(count)
                Self.part(in: vehicle, mesh: .generateCone(height: 0.06, radius: 0.022), material: fin,
                          position: SIMD3(cos(angle) * 0.055, height, sin(angle) * 0.055))
            }
        }
        Self.buildPlume(in: shipPlume)
        Self.buildPlume(in: boosterPlume)
        shipPlume.position.y = -0.41
        boosterPlume.position.y = -0.71
        ship.addChild(shipPlume)
        booster.addChild(boosterPlume)
        var glow = UnlitMaterial(color: UIColor(red: 1, green: 0.4, blue: 0.08, alpha: 1))
        glow.blending = .transparent(opacity: .init(scale: 0.22))
        Self.part(in: heatGlow, mesh: .generateSphere(radius: 0.115), material: glow).scale = SIMD3(1, 3.8, 1)
        ship.addChild(heatGlow)
    }

    private static func buildPlume(in entity: Entity) {
        var exhaust = UnlitMaterial(color: UIColor(red: 0.45, green: 0.65, blue: 1, alpha: 1))
        exhaust.blending = .transparent(opacity: .init(scale: 0.32))
        let outer = part(in: entity, mesh: .generateCone(height: 0.65, radius: 0.08),
                         material: exhaust,
                         position: SIMD3(0, -0.325, 0))
        outer.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        let core = part(in: entity, mesh: .generateSphere(radius: 0.045),
                        material: UnlitMaterial(color: UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1)),
                        position: SIMD3(0, -0.14, 0))
        core.scale = SIMD3(1, 4, 1)
    }

    private static func makeSatellite() -> Entity {
        let satellite = Entity()
        part(in: satellite, mesh: .generateBox(size: SIMD3(0.23, 0.08, 0.3)),
             material: SimpleMaterial(color: .lightGray, roughness: 0.4, isMetallic: true))
        let panels = SimpleMaterial(color: UIColor(red: 0.09, green: 0.24, blue: 0.5, alpha: 1),
                                    roughness: 0.35, isMetallic: true)
        for side: Float in [-1, 1] {
            part(in: satellite, mesh: .generateBox(size: SIMD3(0.6, 0.015, 0.36)),
                 material: panels, position: SIMD3(side * 0.42, 0, 0))
        }
        return satellite
    }

    private static func buildSplash(in entity: Entity) {
        var foam = UnlitMaterial(color: UIColor(white: 0.95, alpha: 1))
        foam.blending = .transparent(opacity: .init(scale: 0.48))
        for index in 0..<12 {
            let angle = Float(index) * 2 * .pi / 12
            let spray = part(in: entity, mesh: .generateSphere(radius: 0.23), material: foam,
                             position: SIMD3(cos(angle), 0.1, sin(angle)))
            spray.scale = SIMD3(1, 0.6, 1)
        }
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
