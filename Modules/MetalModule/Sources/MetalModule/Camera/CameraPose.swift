//
//  CameraPose.swift
//  MetalModule
//
//  Created by max on 31.05.2026.
//

import simd

struct CameraPose: Equatable {
    let target: SIMD3<Float>
    let distance: Float
    let orientation: simd_quatf

    var offset: SIMD3<Float> {
        orientation.act(SIMD3<Float>(0, 0, distance))
    }

    var position: SIMD3<Float> {
        target + offset
    }

    var upVector: SIMD3<Float> {
        orientation.act(SIMD3<Float>(0, 1, 0))
    }

    var transitionFrame: CameraTransition.Frame {
        .init(target: target,
              distance: distance)
    }

    func makeRenderViewMatrix() -> float4x4 {
        float4x4.lookAt(
            eye: offset,
            target: .zero,
            upVector: upVector
        )
    }
}
