import Foundation
import simd

public enum CelestialBodyID: String, CaseIterable, Codable, Sendable {
    case sun = "Sun", mercury = "Mercury", venus = "Venus", earth = "Earth", moon = "Moon"
    case mars = "Mars", jupiter = "Jupiter", saturn = "Saturn", uranus = "Uranus"
    case neptune = "Neptune", pluto = "Pluto"
}

public enum CelestialStateError: Error, LocalizedError, Equatable, Sendable {
    case invalidData
    case outsideCoverage
    case unknownBody

    public var errorDescription: String? {
        switch self {
        case .invalidData: "The offline ephemeris data could not be loaded."
        case .outsideCoverage: "Ephemeris dates must be between 2000 and 2100."
        case .unknownBody: "This object has no ephemeris data."
        }
    }
}

/// Geometric heliocentric vectors in the J2000 ecliptic frame. No light-time correction.
public struct CelestialBodyState: Sendable {
    public let positionKm: SIMD3<Double>
    public let velocityKmPerSecond: SIMD3<Double>
    /// Standard body-fixed axes: +Z pole, +X zero meridian, +Y east longitude 90°.
    public let bodyFixedToEcliptic: simd_double3x3

    var scenePosition: SIMD3<Double> { EphemerisCoordinates.scenePosition(positionKm) }
    var sceneOrientation: float4x4 {
        let basis = EphemerisCoordinates.eclipticToScene
        let matrix = basis * bodyFixedToEcliptic * basis.transpose
        return float4x4(SIMD4(SIMD3<Float>(matrix.columns.0), 0),
                        SIMD4(SIMD3<Float>(matrix.columns.1), 0),
                        SIMD4(SIMD3<Float>(matrix.columns.2), 0), SIMD4(0, 0, 0, 1))
    }
}

protocol CelestialStateProviding: Sendable {
    var coverage: ClosedRange<Double>? { get }
    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState
}

extension CelestialStateProviding {
    var coverage: ClosedRange<Double>? { nil }
}

struct UnavailableCelestialStateProvider: CelestialStateProviding {
    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        throw CelestialStateError.invalidData
    }
}

enum EphemerisCoordinates {
    static let eclipticToScene = simd_double3x3(SIMD3(1, 0, 0), SIMD3(0, 0, -1), SIMD3(0, 1, 0))
    static func scenePosition(_ kilometers: SIMD3<Double>) -> SIMD3<Double> {
        eclipticToScene * kilometers * OrbitalElements.sceneUnitsPerKm
    }
    static func renderPosition(_ absolute: SIMD3<Double>, relativeTo origin: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(absolute - origin)
    }
}

/// Explicit analytic collaborator for synthetic geometry fixtures, never a production fallback.
struct KeplerCelestialStateProvider: CelestialStateProviding {
    let planets: [Planet]
    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        var states: [String: OrbitalState] = [:]
        for planet in planets {
            let relative = planet.orbit?.state(at: seconds) ?? OrbitalState(position: .zero, velocity: .zero)
            let parent = planet.parentName.flatMap { states[$0] }
            states[planet.name] = OrbitalState(position: relative.position + (parent?.position ?? .zero),
                                             velocity: relative.velocity + (parent?.velocity ?? .zero))
        }
        guard let state = states[body.rawValue] else { throw CelestialStateError.unknownBody }
        return CelestialBodyState(positionKm: state.position, velocityKmPerSecond: state.velocity,
                                  bodyFixedToEcliptic: matrix_identity_double3x3)
    }
}
