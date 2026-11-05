import SwiftUI
import XCTest
@testable import OptiUniverse
@testable import UniverseModule

@MainActor
final class OrbitVisibilityTests: XCTestCase {
    func testPreferenceDefaultsToHiddenAndRestoresForNewResources() async throws {
        let suite = "OptiUniverse.OrbitVisibilityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let firstResources = UniverseModuleFactory.makeResources()
        let firstWindow = try host(OrbitVisibilityButton(resources: firstResources).defaultAppStorage(defaults))
        defer { firstWindow.isHidden = true; firstWindow.rootViewController = nil }
        XCTAssertNil(defaults.object(forKey: "showsCelestialOrbits"))
        XCTAssertFalse(firstResources.sceneCoordinator.orbitLinesRoot.isEnabled)

        defaults.set(true, forKey: "showsCelestialOrbits")
        try await waitUntil { firstResources.sceneCoordinator.orbitLinesRoot.isEnabled }
        defaults.set(false, forKey: "showsCelestialOrbits")
        try await waitUntil { !firstResources.sceneCoordinator.orbitLinesRoot.isEnabled }
        defaults.set(true, forKey: "showsCelestialOrbits")
        try await waitUntil { firstResources.sceneCoordinator.orbitLinesRoot.isEnabled }
        firstWindow.isHidden = true
        firstWindow.rootViewController = nil

        let restoredResources = UniverseModuleFactory.makeResources()
        let restoredWindow = try host(OrbitVisibilityButton(resources: restoredResources).defaultAppStorage(defaults))
        defer { restoredWindow.isHidden = true; restoredWindow.rootViewController = nil }
        try await waitUntil { restoredResources.sceneCoordinator.orbitLinesRoot.isEnabled }
        XCTAssertTrue(defaults.bool(forKey: "showsCelestialOrbits"))
    }

    func testToolbarPreferenceChangesKeepSceneInstalledDuringResizing() async throws {
        let suite = "OptiUniverse.OrbitToolbarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ObjectsPreviewModel(presentation: .scene)
        let window = try host(ObjectsPreviewHost(model: model).defaultAppStorage(defaults))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitUntil { model.resources.sceneCoordinator.activeInstallationID != nil }
        let installation = try XCTUnwrap(model.resources.sceneCoordinator.activeInstallationID)
        for (size, visible) in [(CGSize(width: 393, height: 852), true),
                                (CGSize(width: 852, height: 393), false),
                                (CGSize(width: 900, height: 700), true)] {
            defaults.set(visible, forKey: "showsCelestialOrbits")
            window.frame.size = size
            window.layoutIfNeeded()
            try await waitUntil { model.resources.sceneCoordinator.areOrbitLinesVisible == visible }
            XCTAssertEqual(model.resources.sceneCoordinator.activeInstallationID, installation)
        }
    }

    private func host<Content: View>(_ content: Content) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: content.environment(\.scenePhase, .active))
        window.makeKeyAndVisible()
        return window
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(predicate(), "Timed out waiting for orbit visibility")
    }
}
