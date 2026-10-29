import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func viewportResizeUpdatesProjectionWithoutResettingCameraOrRoute() throws {
    let resources = UniverseModuleResources()
    resources.navigationController.applyNavigation(named: "Mars", snapshot: .navigationControllerTestSnapshot)
    resources.beginManualCameraControl()
    resources.cameraState.commit(.init(cameraTarget: SIMD3<Float>(1, 2, 3),
                                       cameraDistance: 8,
                                       cameraOrientation: simd_quatf(angle: 0.4, axis: SIMD3<Float>(0, 1, 0))))
    let pose = resources.cameraState.pose
    let navigation = resources.navigationSnapshot
    #expect(navigation.state == .running)
    #expect(navigation.routeID != nil)
    var previousHorizontalScale: Float?

    // Cover closing, unfolding, and reserving a side panel without a scene remount.
    for size in [CGSize(width: 390, height: 800),
                 CGSize(width: 950, height: 600),
                 CGSize(width: 570, height: 600),
                 CGSize(width: 390, height: 800)] {
        resources.setViewportSize(size)
        let snapshot = resources.snapshotProvider.makeCameraSnapshot(
            dependencies: resizeDependencies(viewportSize: resources.viewportSize)
        )
        #expect(snapshot.viewportSize == size)
        #expect(resources.sceneCoordinator.viewportSize == size)
        #expect(snapshot.cameraRevision == resources.cameraState.revision)
        #expect(resources.cameraState.pose == pose)
        #expect(resources.navigationSnapshot.routeID == navigation.routeID)
        #expect(resources.navigationSnapshot.progress == navigation.progress)
        #expect(resources.navigationSnapshot.state == .running)
        #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
        let expectedAspect = Float(size.width / size.height)
        // The projection maps positive Y upward using a negative vertical scale.
        let actualAspect = -snapshot.projectionMatrix[1][1] / snapshot.projectionMatrix[0][0]
        #expect(abs(actualAspect - expectedAspect) < 0.000_01)
        if let previousHorizontalScale {
            #expect(snapshot.projectionMatrix[0][0] != previousHorizontalScale)
        }
        previousHorizontalScale = snapshot.projectionMatrix[0][0]
    }
}

@MainActor
@Test(arguments: [CGSize.zero,
                  CGSize(width: -1, height: 500),
                  CGSize(width: 400, height: 0),
                  CGSize(width: CGFloat.nan, height: 500),
                  CGSize(width: 400, height: CGFloat.infinity)])
func viewportResizeIgnoresInvalidTransientGeometry(size: CGSize) {
    let resources = UniverseModuleResources()
    let validSize = CGSize(width: 390, height: 800)
    resources.setViewportSize(validSize)

    resources.setViewportSize(size)
    resources.sceneCoordinator.setViewportSize(size)

    #expect(resources.viewportSize == validSize)
    #expect(resources.sceneCoordinator.viewportSize == validSize)
}

private func resizeDependencies(viewportSize: CGSize) -> CameraSnapshotDependencies {
    CameraSnapshotDependencies(followedObject: nil,
                               transfer: nil,
                               activeCameraMotionRevision: 0,
                               sceneFrameID: nil,
                               viewportSize: viewportSize,
                               projection: CameraProjectionParameters(nearPlane: 0.1, farPlane: 100))
}
