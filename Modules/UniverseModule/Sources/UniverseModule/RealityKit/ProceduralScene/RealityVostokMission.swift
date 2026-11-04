import RealityKit
import UIKit

/// The model hierarchy is allocated once. Flight samples only move or hide existing entities.
@MainActor
final class RealityVostokMission {
    private struct Stage {
        let entity: Entity
        let cue: VostokFlightCue
        let drift: SIMD3<Float>
        let tiltAxis: SIMD3<Float>
        let linger: Double
    }

    let root = Entity()
    private let capsule = Entity()
    private let serviceModule = Entity()
    private let pilot = Entity()
    private let capsuleChute = Entity()
    private let pilotChute = Entity()
    private let launchPlume = Entity()
    private let upperPlume = Entity()
    private let brakePlume = Entity()
    private let entryGlow = Entity()
    private var stages: [Stage] = []

    init() {
        root.name = "Vostok1"
        capsule.name = "VostokDescentModule"
        serviceModule.name = "VostokInstrumentModule"
        pilot.name = "YuriGagarin"
        for entity in [capsule, serviceModule, pilot] { root.addChild(entity) }
        buildSpacecraft()
        buildLauncher()
        buildPilot()
        root.isEnabled = false
    }

    func update(state: NavigationRouteRenderState, sceneOrigin: SIMD3<Double>) {
        guard let profile = state.route?.vostokProfile, let flight = state.vostokFlight else {
            root.isEnabled = false
            return
        }
        root.isEnabled = true
        let time = state.elapsedTime
        let size = profile.vehicleSize(at: time)
        let landing = time >= VostokFlightCue.ejection.rawValue
        apply(flight.capsule, to: capsule, size: size, origin: sceneOrigin)
        // The two mapped sites are closer than the enlarged models. Widen the
        // final staging around those sites while leaving the physical route intact.
        let spread = Crew13RouteProfile.smooth(Float((time - 53) / 4))
        let staging = normalize(cross(flight.surfaceUp, profile.normal)) * size * spread * 0.72
        if landing { capsule.position += flight.surfaceUp * size * 0.38 + staging }
        let fairingClear = VostokFlightCue.fairing.rawValue + 0.55
        capsule.isEnabled = time >= fairingClear
        serviceModule.isEnabled = time >= fairingClear && time < VostokFlightCue.entry.rawValue + 2.5
        if serviceModule.isEnabled {
            updateServiceModule(flight: flight, profile: profile, time: time, origin: sceneOrigin)
        }
        updatePilot(flight.pilot, size: size, time: time, origin: sceneOrigin)
        pilot.position -= staging
        updateChute(capsuleChute, time: time, opening: VostokFlightCue.parachutes.rawValue + 0.6,
                    touchdown: VostokFlightCue.capsuleLanded.rawValue)
        updateEffects(flight: flight, time: time)
        for stage in stages {
            updateStage(stage, flight: flight, profile: profile, time: time, origin: sceneOrigin)
        }
    }

    private func updateServiceModule(flight: VostokFlightState, profile: VostokRouteProfile,
                                     time: TimeInterval, origin: SIMD3<Double>) {
        let entry = VostokFlightCue.entry.rawValue
        let detached = time >= entry
        let reference = detached ? profile.sample(time: entry) : flight
        let size = profile.vehicleScale
        apply(reference.capsule, to: serviceModule, size: size, origin: origin)
        let separation = Float(max(0, time - entry))
        let local = SIMD3<Float>(separation * 1.3, -0.68 - separation * 1.5, 0)
        serviceModule.position += serviceModule.orientation.act(local * size)
        serviceModule.orientation *= simd_quatf(angle: separation, axis: SIMD3<Float>(0, 0, 1))
    }

    private func updatePilot(_ pose: MissionVehiclePose?, size: Float, time: TimeInterval, origin: SIMD3<Double>) {
        pilot.isEnabled = pose != nil
        guard let pose else { return }
        apply(pose, to: pilot, size: size, origin: origin)
        pilot.position += pose.orientation.act(SIMD3<Float>(0, 0.35 * size, 0))
        updateChute(pilotChute, time: time, opening: VostokFlightCue.parachutes.rawValue,
                    touchdown: VostokFlightCue.pilotLanded.rawValue)
    }

    private func updateStage(_ stage: Stage, flight: VostokFlightState, profile: VostokRouteProfile,
                             time: TimeInterval, origin: SIMD3<Double>) {
        let separation = time - stage.cue.rawValue
        stage.entity.isEnabled = separation < stage.linger
        guard stage.entity.isEnabled else { return }
        let reference = separation >= 0 ? profile.sample(time: stage.cue.rawValue) : flight
        apply(reference.capsule, to: stage.entity, size: profile.vehicleScale, origin: origin)
        let drift = Float(max(separation, 0))
        stage.entity.position += stage.entity.orientation.act(stage.drift * drift * profile.vehicleScale)
        stage.entity.orientation *= simd_quatf(angle: drift * 0.6, axis: stage.tiltAxis)
    }

    private func updateChute(_ chute: Entity, time: TimeInterval, opening: TimeInterval, touchdown: TimeInterval) {
        chute.isEnabled = time >= opening && time < touchdown + 0.8
        let inflation = Crew13RouteProfile.smooth(Float((time - opening) / 0.55))
        let collapse = Crew13RouteProfile.smooth(Float((time - touchdown) / 0.8))
        chute.scale = SIMD3(repeating: max(0.01, inflation * (1 - collapse)))
    }

    private func updateEffects(flight: VostokFlightState, time: TimeInterval) {
        let flicker = 1 + 0.08 * sin(Float(time) * 38)
        launchPlume.isEnabled = time < VostokFlightCue.core.rawValue
        upperPlume.isEnabled = time >= VostokFlightCue.core.rawValue && time < VostokFlightCue.orbit.rawValue
        launchPlume.scale.y = flicker
        upperPlume.scale.y = flicker
        brakePlume.isEnabled = flight.retrofire > 0.01
        brakePlume.scale.y = max(0.01, flight.retrofire * flicker)
        entryGlow.isEnabled = flight.entryGlow > 0.01
        entryGlow.scale = SIMD3(0.8, 0.9 + flight.entryGlow, 0.8)
    }

    private func apply(_ pose: MissionVehiclePose, to entity: Entity, size: Float, origin: SIMD3<Double>) {
        entity.position = EphemerisCoordinates.renderPosition(pose.precisePosition, relativeTo: origin)
        entity.orientation = pose.orientation
        entity.scale = SIMD3(repeating: size)
    }

    private func buildSpacecraft() {
        let metal = SimpleMaterial(color: .lightGray, roughness: 0.44, isMetallic: true)
        let dark = SimpleMaterial(color: .darkGray, roughness: 0.55, isMetallic: true)
        let glass = SimpleMaterial(color: .init(red: 0.08, green: 0.17, blue: 0.25, alpha: 1),
                                   roughness: 0.22, isMetallic: true)
        part(capsule, .generateSphere(radius: 0.38), metal)
        for angle: Float in [0, 2 * .pi / 3, 4 * .pi / 3] {
            let port = Entity()
            port.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            part(port, .generateSphere(radius: 0.105), dark, SIMD3(0, 0.11, 0.34)).scale.z = 0.44
            part(port, .generateSphere(radius: 0.075), glass, SIMD3(0, 0.11, 0.381)).scale.z = 0.35
            capsule.addChild(port)
        }
        part(serviceModule, .generateCone(height: 0.82, radius: 0.43), metal)
        part(serviceModule, .generateCylinder(height: 0.17, radius: 0.39), dark, SIMD3(0, -0.31, 0))
        part(serviceModule, .generateCylinder(height: 0.14, radius: 0.17), metal, SIMD3(0, -0.46, 0))
        serviceModule.addChild(brakePlume)
        buildPlume(brakePlume, length: 0.62, radius: 0.16)
        brakePlume.position.y = -0.51

        let hot = UnlitMaterial(color: .init(red: 1, green: 0.28, blue: 0.04, alpha: 0.76))
        part(entryGlow, .generateCone(height: 1.08, radius: 0.41), hot, SIMD3(0, -0.53, 0))
            .orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        capsule.addChild(entryGlow)
        buildChute(capsuleChute, color: .systemOrange, radius: 0.79)
        capsule.addChild(capsuleChute)
    }

    private func buildLauncher() {
        let green = SimpleMaterial(color: .init(red: 0.42, green: 0.46, blue: 0.38, alpha: 1),
                                   roughness: 0.66, isMetallic: false)
        let white = SimpleMaterial(color: .init(white: 0.91, alpha: 1), roughness: 0.6, isMetallic: false)
        let band = SimpleMaterial(color: .init(red: 0.66, green: 0.22, blue: 0.11, alpha: 1),
                                  roughness: 0.55, isMetallic: false)
        let core = stage(.core, drift: SIMD3(0, -2.6, 0.4), axis: SIMD3(1, 0, 0), linger: 2)
        part(core, .generateCylinder(height: 2.28, radius: 0.29), green, SIMD3(0, -2.85, 0))
        part(core, .generateCylinder(height: 0.25, radius: 0.3), band, SIMD3(0, -3.88, 0))
        core.addChild(launchPlume)
        launchPlume.position.y = -4
        buildPlume(launchPlume, length: 1.7, radius: 0.27)

        let upper = stage(.orbit, drift: SIMD3(0, -1.7, 0.3), axis: SIMD3(0, 0, 1), linger: 2)
        part(upper, .generateCylinder(height: 0.75, radius: 0.3), green, SIMD3(0, -1.32, 0))
        part(upper, .generateCylinder(height: 0.16, radius: 0.29), white, SIMD3(0, -1.03, 0))
        upper.addChild(upperPlume)
        upperPlume.position.y = -1.7
        buildPlume(upperPlume, length: 1.03, radius: 0.2)

        for index in 0..<4 {
            let angle = Float(index) * .pi / 2
            let radial = SIMD3<Float>(cos(angle), 0, sin(angle))
            let axis = SIMD3<Float>(radial.z, 0, -radial.x)
            let booster = stage(.boosters, drift: radial * 1.05 + SIMD3(0, -1.95, 0), axis: axis, linger: 2.3)
            part(booster, .generateCylinder(height: 1.16, radius: 0.21), white,
                 radial * 0.39 + SIMD3(0, -3.36, 0))
            part(booster, .generateCone(height: 1.35, radius: 0.21), green,
                 radial * 0.39 + SIMD3(0, -2.105, 0))
            part(booster, .generateCylinder(height: 0.14, radius: 0.213), band,
                 radial * 0.39 + SIMD3(0, -3.88, 0))
        }
        for side: Float in [-1, 1] {
            let fairing = stage(.fairing, drift: SIMD3(side * 1.6, -1.35, 0),
                                axis: SIMD3(0, 0, -side), linger: 1.8)
            let shell = part(fairing, .generateSphere(radius: 0.53), white, SIMD3(side * 0.17, -0.13, 0))
            shell.scale = SIMD3(0.68, 1.75, 1)
        }
    }

    private func stage(_ cue: VostokFlightCue, drift: SIMD3<Float>, axis: SIMD3<Float>, linger: Double) -> Entity {
        let entity = Entity()
        root.addChild(entity)
        stages.append(Stage(entity: entity, cue: cue, drift: drift, tiltAxis: axis, linger: linger))
        return entity
    }

    private func buildPilot() {
        let suit = SimpleMaterial(color: .systemOrange, roughness: 0.7, isMetallic: false)
        let helmet = SimpleMaterial(color: .white, roughness: 0.35, isMetallic: false)
        let dark = SimpleMaterial(color: .darkGray, roughness: 0.6, isMetallic: false)
        part(pilot, .generateBox(size: SIMD3(0.24, 0.31, 0.17), cornerRadius: 0.06), suit)
        part(pilot, .generateSphere(radius: 0.117), helmet, SIMD3(0, 0.24, 0))
        part(pilot, .generateSphere(radius: 0.075), dark, SIMD3(0, 0.24, 0.086)).scale.z = 0.5
        for side: Float in [-1, 1] {
            part(pilot, .generateCylinder(height: 0.24, radius: 0.045), suit, SIMD3(side * 0.16, 0.02, 0))
                .orientation = simd_quatf(angle: -side * 0.48, axis: SIMD3(0, 0, 1))
            part(pilot, .generateCylinder(height: 0.19, radius: 0.054), suit, SIMD3(side * 0.067, -0.23, 0))
        }
        buildChute(pilotChute, color: .white, radius: 0.66)
        pilot.addChild(pilotChute)
    }

    private func buildChute(_ parent: Entity, color: UIColor, radius: Float) {
        let fabric = SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)
        let cord = SimpleMaterial(color: .lightGray, roughness: 0.9, isMetallic: false)
        part(parent, .generateSphere(radius: radius), fabric, SIMD3(0, 1.22, 0)).scale.y = 0.29
        for index in 0..<8 {
            let angle = Float(index) * .pi / 4
            let rim = SIMD3<Float>(cos(angle) * radius * 0.93, 1.18, sin(angle) * radius * 0.93)
            let attachment = SIMD3<Float>(0, 0.27, 0)
            let line = rim - attachment
            part(parent, .generateCylinder(height: length(line), radius: 0.009), cord, (rim + attachment) * 0.5)
                .orientation = simd_quatf(from: SIMD3(0, 1, 0), to: normalize(line))
        }
    }

    private func buildPlume(_ parent: Entity, length: Float, radius: Float) {
        let outer = UnlitMaterial(color: .init(red: 1, green: 0.38, blue: 0.09, alpha: 1))
        let inner = UnlitMaterial(color: .init(red: 1, green: 0.86, blue: 0.62, alpha: 1))
        part(parent, .generateCone(height: length, radius: radius), outer, SIMD3(0, -length * 0.5, 0))
            .orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        part(parent, .generateCone(height: length * 0.4, radius: radius * 0.85), inner,
             SIMD3(0, -length * 0.14, 0)).orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
    }

    @discardableResult
    private func part(_ parent: Entity, _ mesh: MeshResource, _ material: any Material,
                      _ position: SIMD3<Float> = .zero) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        parent.addChild(entity)
        return entity
    }
}
