import simd

struct Planet: Sendable {
    let name: String
    let meshName: String
    let parentName: String?
    let radius: Float
    let orbit: OrbitalElements?

    nonisolated func orbitTransformMatrix(at time: Double,
                                          parentWorldPosition: SIMD3<Float>? = nil) -> float4x4 {
        let offset = orbit.map { OrbitalState.scenePosition($0.state(at: time).position) } ?? .zero
        return float4x4.makeTranslation((parentWorldPosition ?? .zero) + offset)
    }
}
