import BaseModule
import SwiftUI
import XCTest
@testable import OptiUniverse
@testable import UniverseModule

/// Exercise real mounted views: geometry and presentation changes must not reinstall RealityView.
@MainActor
final class ObjectsViewLifecycleTests: XCTestCase {
    func testScenePreviewOpensObjectsWithoutHome() async throws {
        let model = ObjectsPreviewModel(presentation: .scene)
        let window = try host(ObjectsPreviewHost(model: model))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitUntil { model.resources.sceneCoordinator.activeInstallationID != nil }
        XCTAssertTrue(isObjectsScreen(model.environment.currentScreen))
        XCTAssertEqual(model.environment.selectedPlanet, "Mars")
        XCTAssertEqual(model.destination?.id, model.environment.selectedDestinationID)
        XCTAssertEqual(model.objectsViewState, .raw)
        XCTAssertFalse(model.environment.destinationsProvider.destinations.isEmpty)
        try await Task.sleep(for: .seconds(1))
        attach(window, name: "Objects-scene")
    }

    func testDetailsPreviewKeepsInstallationThroughLayoutChangesAndRouteAction() async throws {
        let model = ObjectsPreviewModel(presentation: .details)
        let window = try host(ObjectsPreviewHost(model: model))
        defer { window.isHidden = true; window.rootViewController = nil }
        window.frame.size = CGSize(width: 393, height: 852)
        window.layoutIfNeeded()
        try await waitUntil {
            if case .info = model.objectsViewState { return true }
            return false
        }
        try await waitUntil {
            model.resources.objectInfoOverlayFramingState.advance(delta: 0).verticalCenterOffset < 0
        }
        let installation = try XCTUnwrap(model.resources.sceneCoordinator.activeInstallationID)
        for size in [CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
                     CGSize(width: 700, height: 700), CGSize(width: 900, height: 700),
                     CGSize(width: 600, height: 700)] {
            window.frame.size = size
            window.layoutIfNeeded()
            try await Task.sleep(for: .seconds(1))
            XCTAssertEqual(model.resources.sceneCoordinator.activeInstallationID, installation)
            XCTAssertEqual(model.resources.viewportSize.width, size.width, accuracy: 0.5)
            XCTAssertEqual(model.resources.viewportSize.height, size.height, accuracy: 0.5)
            guard case .info(let entity) = model.objectsViewState else {
                XCTFail("Resizing dismissed details")
                return
            }
            XCTAssertEqual(entity.id, model.destination?.id)
            attach(window, name: "Objects-details-\(Int(size.width))x\(Int(size.height))")
        }
        guard case .info(let entity) = model.objectsViewState else { return }
        entity.navigationButtonAction()
        XCTAssertEqual(model.objectsViewState, .orbit)
        XCTAssertEqual(model.resources.transferPreviewSnapshot.destinationName, "Mars")
    }

    func testRoutePreviewInitializesAfterSelectionAndOnlyOnce() async throws {
        let model = ObjectsPreviewModel(presentation: .route)
        let window = try host(ObjectsPreviewHost(model: model))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitUntil { model.resources.transferPreviewSnapshot.status == .ready }
        XCTAssertEqual(model.objectsViewState, .orbit)
        XCTAssertEqual(model.resources.transferPreviewSnapshot.destinationName, "Mars")
        let installation = try XCTUnwrap(model.resources.sceneCoordinator.activeInstallationID)
        model.resources.rotateCamera(translation: CGSize(width: 30, height: 10))
        let pose = model.resources.cameraState.pose
        window.frame.size = CGSize(width: 900, height: 700)
        window.layoutIfNeeded()
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(model.resources.sceneCoordinator.activeInstallationID, installation)
        XCTAssertEqual(model.resources.cameraState.pose, pose)
        XCTAssertEqual(model.resources.transferPreviewSnapshot.status, .ready)
        attach(window, name: "Objects-transfer-route")
        model.closeRoute()
        model.sceneDidAppear()
        XCTAssertEqual(model.objectsViewState, .raw)
        XCTAssertEqual(model.resources.transferPreviewSnapshot.status, .inactive)
        let destination = try XCTUnwrap(model.destination)
        model.startNavigation(destinationID: destination.id)
        try await waitUntil { model.resources.navigation.navigationSnapshot.state == .running }
        let navigation = model.resources.navigation.navigationSnapshot
        window.frame.size = CGSize(width: 393, height: 852)
        window.layoutIfNeeded()
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(model.resources.sceneCoordinator.activeInstallationID, installation)
        XCTAssertEqual(model.resources.navigation.navigationSnapshot.routeID, navigation.routeID)
        XCTAssertLessThan(model.resources.navigation.navigationSnapshot.remainingTime, navigation.remainingTime)
        model.cancelNavigation()
    }

    func testRootKeepsSceneMountedAcrossHomeRoundTrips() async throws {
        let environment = AppEnvironment()
        let resources = UniverseModuleFactory.makeResources()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OptiUniverse.ObjectsLifecycleTests"))
        let window = try host(RootContainerView(universeResources: resources)
            .environment(environment)
            .environment(ReviewRequestCoordinator(defaults: defaults)))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitUntil { resources.sceneCoordinator.activeInstallationID != nil }
        let installation = resources.sceneCoordinator.activeInstallationID
        let mars = try XCTUnwrap(environment.destinationsProvider.destinations.first { $0.title == "Mars" })
        environment.selectedDestinationID = mars.id
        environment.selectedPlanet = mars.object
        for screen in [AppEnvironment.Screen.objects, .home, .objects] {
            environment.currentScreen = screen
            try await Task.sleep(for: .milliseconds(500))
            XCTAssertEqual(resources.sceneCoordinator.activeInstallationID, installation)
        }
    }

    private func host<Content: View>(_ content: Content) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        // A UIKit test window has no SwiftUI Scene to supply the foreground phase.
        window.rootViewController = UIHostingController(rootView: content.environment(\.scenePhase, .active))
        window.makeKeyAndVisible()
        return window
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(predicate(), "Timed out waiting for the prepared scene")
    }

    private func attach(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
