import Testing
import UIKit
@testable import UniverseModule

@MainActor
@Test func cameraGestureViewInstallsExistingCameraControls() throws {
    let resources = UniverseModuleResources()
    let controller = CameraController(
        cameraCoordinator: resources.cameraCoordinator,
        beginManualCameraControl: {},
        isTrajectoryModeActive: { true }
    )
    let view = UIView()

    CameraGestureView.installGestureRecognizers(
        on: view,
        cameraController: controller
    )

    let recognizers = try #require(view.gestureRecognizers)
    #expect(recognizers.count == 4)
    let pans = recognizers.compactMap { $0 as? UIPanGestureRecognizer }
    #expect(pans.count == 2)
    #expect(pans.contains {
        $0.minimumNumberOfTouches == 1 && $0.maximumNumberOfTouches == 1
    })
    let trajectoryPan = try #require(pans.first {
        $0.minimumNumberOfTouches == 2 && $0.maximumNumberOfTouches == 2
    })
    #expect(trajectoryPan.delegate === controller)
    #expect(recognizers.contains { $0 is UIPinchGestureRecognizer })
    #expect(recognizers.contains { $0 is UIRotationGestureRecognizer })
}

@MainActor
@Test func trajectoryPanBeginsOnlyWhileTrajectoryModeIsActive() throws {
    let resources = UniverseModuleResources()
    var isTrajectoryModeActive = false
    let controller = CameraController(
        cameraCoordinator: resources.cameraCoordinator,
        beginManualCameraControl: {},
        isTrajectoryModeActive: { isTrajectoryModeActive }
    )
    let trajectoryPan = UIPanGestureRecognizer()
    trajectoryPan.minimumNumberOfTouches = 2
    trajectoryPan.maximumNumberOfTouches = 2

    #expect(!controller.gestureRecognizerShouldBegin(trajectoryPan))
    isTrajectoryModeActive = true
    #expect(controller.gestureRecognizerShouldBegin(trajectoryPan))
}
