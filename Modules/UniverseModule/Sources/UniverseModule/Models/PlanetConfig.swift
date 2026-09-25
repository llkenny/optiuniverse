struct PlanetConfig: Decodable {
    let name: String
    let meshName: String
    let diameterKm: Float
    let parentName: String?
    let orbit: OrbitalElements?
    let rotationSpeedKmSec: Float
}
