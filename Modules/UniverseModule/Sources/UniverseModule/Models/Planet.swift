import simd

struct Planet: Sendable {
    let name: String
    let meshName: String
    let parentName: String?
    let radius: Float
    let orbit: OrbitalElements?
    let rotationSpeedKmSec: Float

    nonisolated func orbitTransformMatrix(at time: Double,
                                          parentWorldPosition: SIMD3<Float>? = nil) -> float4x4 {
        let offset = orbit.map { OrbitalState.scenePosition($0.state(at: time).position) } ?? .zero
        return float4x4.makeTranslation((parentWorldPosition ?? .zero) + offset)
    }

    nonisolated func visualRotationMatrix(at presentationTime: Float) -> float4x4 {
        float4x4.makeRotationY(presentationTime * rotationSpeedKmSec)
    }

    nonisolated func modelMatrix(at time: Double,
                                 presentationTime: Float = 0,
                                 parentWorldPosition: SIMD3<Float>? = nil) -> float4x4 {
        orbitTransformMatrix(at: time, parentWorldPosition: parentWorldPosition) *
            visualRotationMatrix(at: presentationTime)
    }
}
