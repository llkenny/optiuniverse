//
//  MatrixExtensions.swift
//  OptiUniverse
//
//  Created by max on 24.07.2025.
//

import simd

extension float4x4 {
    static func makeTranslation(_ t: SIMD3<Float>) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [t.x, t.y, t.z, 1]
        )
    }
    
    static func makeRotationX(_ angle: Float) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, cos(angle), -sin(angle), 0],
            [0, sin(angle), cos(angle), 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeRotationY(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), 0, -sin(angle), 0],
            [0, 1, 0, 0],
            [sin(angle), 0, cos(angle), 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeRotationZ(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeScale(_ s: SIMD3<Float>) -> float4x4 {
        float4x4(
            [s.x, 0,   0,   0],
            [0,   s.y, 0,   0],
            [0,   0,   s.z, 0],
            [0,   0,   0,   1]
        )
    }
    
    static func lookAt(eye: SIMD3<Float>,
                       target: SIMD3<Float>,
                       up: SIMD3<Float>) -> float4x4 {
        // Forward vector from the eye to the target
        let f = normalize(target - eye)
        // Right vector orthogonal to the forward direction
        let s = normalize(cross(f, up))
        // Recomputed up vector to ensure orthogonality
        let u = cross(s, f)

        return float4x4(
            [ s.x,  s.y,  s.z, -dot(s, eye) ],
            [ u.x,  u.y,  u.z, -dot(u, eye) ],
            [ -f.x, -f.y, -f.z,  dot(f, eye) ],
            [ 0,    0,    0,     1 ]
        )
    }
    
    static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = far / (far - near)
        let w = -far * near / (far - near)
        
        // Metal's clip space uses a right-handed system with Y pointing up.
        // The viewport transform converts to the top-left origin automatically,
        // so no Y inversion is necessary in this projection matrix.
        return float4x4(
            [x, 0, 0, 0],
            [0, y, 0, 0],
            [0, 0, z, 1],
            [0, 0, w, 0]
        )
    }
}
