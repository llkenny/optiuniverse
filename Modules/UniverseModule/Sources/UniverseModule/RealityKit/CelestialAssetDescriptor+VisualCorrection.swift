import RealityKit
import simd

extension CelestialAssetDescriptor {
    var visualCorrectionTransform: Transform {
        let renderScale = modelToUniverseScale * (renderRadius / referenceRadius)
        return Transform(
            scale: SIMD3<Float>(repeating: renderScale),
            rotation: simd_quatf(
                ix: orientationCorrection.xAxis,
                iy: orientationCorrection.yAxis,
                iz: orientationCorrection.zAxis,
                r: orientationCorrection.real
            ),
            translation: SIMD3<Float>(
                pivotCorrection.xAxis,
                pivotCorrection.yAxis,
                pivotCorrection.zAxis
            )
        )
    }
}
