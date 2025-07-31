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
            [0, cos(angle), sin(angle), 0],
            [0, -sin(angle), cos(angle), 0],
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
    
    static func makePerspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let scaleY = 1 / tan(fovY * 0.5)
        let scaleX = scaleY / aspect
        let scaleZ = far / (far - near)
        let scaleW = -far * near / (far - near)
        
        return .init(
            [scaleX, 0, 0, 0],
            [0, scaleY, 0, 0],
            [0, 0, scaleZ, 1],
            [0, 0, scaleW, 0]
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
}

