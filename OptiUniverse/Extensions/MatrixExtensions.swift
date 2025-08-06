//
//  MatrixExtensions.swift
//  OptiUniverse
//
//  Created by max on 24.07.2025.
//

// MatrixExtensions.swift
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
    
    /// Creates a rotation matrix around a specified point.
    ///
    /// - Parameters:
    ///   - angle: The angle of rotation in radians.
    ///   - axis: The axis of rotation (e.g., `float3(1, 0, 0)` for X-axis).
    ///   - point: The point around which to rotate.
    /// - Returns: A `float4x4` matrix representing the rotation.
    static func rotation(angle: Float, axis: SIMD3<Float>, around point: SIMD3<Float>) -> float4x4 {
        // 1. Translate the object so the rotation point is at the origin.
        let translateToOrigin = float4x4(translation: -point)
        
        // 2. Apply the rotation around the origin.
        let rotationMatrix = float4x4(rotation: angle, axis: axis)
        
        // 3. Translate the object back.
        let translateBack = float4x4(translation: point)
        
        // Combine the transformations: T_back * R * T_to_origin
        return translateBack * rotationMatrix * translateToOrigin
    }
    
    /// Helper initializer for creating a translation matrix.
    init(translation vector: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(vector.x, vector.y, vector.z, 1)
        )
    }
    
    /// Helper initializer for creating a rotation matrix from an angle and axis.
    init(rotation angle: Float, axis: SIMD3<Float>) {
        self = matrix_identity_float4x4
        let normalizedAxis = normalize(axis)
        let c = cos(angle)
        let s = sin(angle)
        let omc = 1.0 - c
        
        let x = normalizedAxis.x
        let y = normalizedAxis.y
        let z = normalizedAxis.z
        
        columns.0.x = x * x * omc + c
        columns.0.y = y * x * omc + z * s
        columns.0.z = z * x * omc - y * s
        
        columns.1.x = x * y * omc - z * s
        columns.1.y = y * y * omc + c
        columns.1.z = z * y * omc + x * s
        
        columns.2.x = x * z * omc + y * s
        columns.2.y = y * z * omc - x * s
        columns.2.z = z * z * omc + c
    }
    
    static func makeScale(_ s: SIMD3<Float>) -> float4x4 {
        float4x4(
            [s.x, 0,   0,   0],
            [0,   s.y, 0,   0],
            [0,   0,   s.z, 0],
            [0,   0,   0,   1]
        )
    }
    
//    // Camera view matrix
//    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
//        let z = normalize(eye - target)
//        let x = normalize(cross(up, z))
//        let y = cross(z, x)
//        
//        return float4x4(
//            [x.x, y.x, z.x, 0],
//            [x.y, y.y, z.y, 0],
//            [x.z, y.z, z.z, 0],
//            [-dot(x, eye), -dot(y, eye), -dot(z, eye), 1]
//        )
//    }
}
