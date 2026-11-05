import simd

enum OrbitLineGeometry {
    /// Expand in the camera's image plane, scaling each endpoint independently.
    /// Midpoint-only widths become large wedges when an orbit passes close to the camera.
    static func positions(start: SIMD3<Float>, end: SIMD3<Float>, view: float4x4,
                          inverseView: float4x4, halfWidthAtUnitDepth: Float) -> [SIMD3<Float>] {
        let first = view * SIMD4(start, 1)
        let last = view * SIMD4(end, 1)
        var cameraStart = SIMD3(first.x, first.y, first.z)
        var cameraEnd = SIMD3(last.x, last.y, last.z)
        let near = CameraFit.minimumNearPlane
        guard cameraStart.z > near || cameraEnd.z > near else { return [] }
        // The renderer's camera looks along +Z. Clip before dividing by depth so
        // segments crossing the camera plane never create an enormous ribbon.
        if cameraStart.z < near {
            let fraction = (near - cameraStart.z) / (cameraEnd.z - cameraStart.z)
            cameraStart += (cameraEnd - cameraStart) * fraction
            cameraStart.z = near
        }
        if cameraEnd.z < near {
            let fraction = (near - cameraEnd.z) / (cameraStart.z - cameraEnd.z)
            cameraEnd += (cameraStart - cameraEnd) * fraction
            cameraEnd.z = near
        }
        let projectedStart = SIMD2(cameraStart.x, cameraStart.y) / cameraStart.z
        let projectedEnd = SIMD2(cameraEnd.x, cameraEnd.y) / cameraEnd.z
        let direction = projectedEnd - projectedStart
        guard simd_length_squared(direction) > 1e-16 else { return [] }
        let perpendicular = simd_normalize(SIMD3(-direction.y, direction.x, 0))
        let startOffset = perpendicular * halfWidthAtUnitDepth * cameraStart.z
        let endOffset = perpendicular * halfWidthAtUnitDepth * cameraEnd.z
        return [cameraStart - startOffset, cameraStart + startOffset,
                cameraEnd - endOffset, cameraEnd + endOffset].map {
            let position = inverseView * SIMD4($0, 1)
            return SIMD3(position.x, position.y, position.z)
        }
    }
}
