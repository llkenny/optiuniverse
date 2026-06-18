//
//  CameraSnapshotDependencies.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

import CoreFoundation

struct CameraSnapshotDependencies: Equatable {
    let followedObject: CameraFollowSnapshotDependency?
    let navigation: CameraNavigationSnapshotDependency?
    let transfer: CameraTransferSnapshotDependency?
    let activeCameraMotionRevision: Int
    let sceneFrameID: UInt64?
    let viewportSize: CGSize
    let projection: CameraProjectionParameters
}
