//
//  CameraProjectionParameters.swift
//  MetalModule
//
//  Created by max on 31.05.2026.
//

struct CameraProjectionParameters: Equatable {
    let nearPlane: Float
    let farPlane: Float
    let verticalFieldOfView: Float
    let verticalCenterOffset: Float

    init(nearPlane: Float,
         farPlane: Float,
         verticalFieldOfView: Float = CameraFit.verticalFieldOfView,
         verticalCenterOffset: Float = 0) {
        self.nearPlane = nearPlane
        self.farPlane = farPlane
        self.verticalFieldOfView = verticalFieldOfView
        self.verticalCenterOffset = verticalCenterOffset
    }

    func withClippingPlanes(nearPlane: Float? = nil,
                            farPlane: Float? = nil) -> CameraProjectionParameters {
        CameraProjectionParameters(
            nearPlane: nearPlane ?? self.nearPlane,
            farPlane: farPlane ?? self.farPlane,
            verticalFieldOfView: verticalFieldOfView,
            verticalCenterOffset: verticalCenterOffset
        )
    }
}
