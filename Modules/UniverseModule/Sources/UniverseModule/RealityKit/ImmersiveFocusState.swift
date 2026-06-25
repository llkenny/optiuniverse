import CoreGraphics
import simd

struct ImmersiveFocusState: Equatable {
    static let targetCenter = SIMD3<Float>(0, 0, -1.2)
    static let targetVisualRadius: Float = 0.35
    static let minimumZoomMultiplier: Float = 0.5
    static let maximumZoomMultiplier: Float = 2.5

    private static let rotationSpeed: Float = 0.006
    private static let maximumPitch: Float = .pi * 0.45
    private static let minimumFramingRadius: Float = 0.0001

    private(set) var bodyName: String?
    private(set) var zoomMultiplier: Float = 1
    private(set) var yaw: Float = 0
    private(set) var pitch: Float = 0

    var hasFocus: Bool {
        bodyName != nil
    }

    mutating func focus(on bodyName: String) {
        guard self.bodyName != bodyName else { return }
        self.bodyName = bodyName
        zoomMultiplier = 1
        yaw = 0
        pitch = 0
    }

    mutating func clear() {
        bodyName = nil
        zoomMultiplier = 1
        yaw = 0
        pitch = 0
    }

    mutating func rotate(translation: CGSize) -> Bool {
        guard hasFocus else { return false }

        yaw += Float(translation.width) * Self.rotationSpeed
        pitch = Self.clamp(
            pitch + Float(translation.height) * Self.rotationSpeed,
            min: -Self.maximumPitch,
            max: Self.maximumPitch
        )
        return true
    }

    mutating func scale(by multiplier: Float) -> Bool {
        guard hasFocus,
              multiplier.isFinite,
              multiplier > 0 else {
            return false
        }

        zoomMultiplier = Self.clamp(
            zoomMultiplier * multiplier,
            min: Self.minimumZoomMultiplier,
            max: Self.maximumZoomMultiplier
        )
        return true
    }

    func transform(
        selectedBodyPositionAfterSceneOrigin: SIMD3<Float>,
        framingRadius: Float
    ) -> float4x4? {
        guard hasFocus,
              selectedBodyPositionAfterSceneOrigin.isFinite,
              framingRadius.isFinite else {
            return nil
        }

        let resolvedFramingRadius = max(framingRadius, Self.minimumFramingRadius)
        let focusScale = (Self.targetVisualRadius * zoomMultiplier) / resolvedFramingRadius
        let rotation = float4x4.makeRotationY(yaw) * float4x4.makeRotationX(pitch)

        return float4x4.makeTranslation(Self.targetCenter)
            * rotation
            * float4x4.makeScale(SIMD3<Float>(repeating: focusScale))
            * float4x4.makeTranslation(-selectedBodyPositionAfterSceneOrigin)
    }

    private static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }
}

private extension SIMD3 where Scalar == Float {
    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
