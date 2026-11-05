import Observation
import SwiftUI
import XCTest
@testable import OptiUniverse

@MainActor
final class N1LaunchPresentationTests: XCTestCase {
    func testForegroundClockPausesAndDisappearanceCancelsCompletion() async throws {
        let fixture = LaunchPresentationFixture()
        let window = try host(LaunchPresentationHost(fixture: fixture))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(100))
        fixture.phase = .background
        fixture.isReady = true
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(fixture.completions, 0)
        fixture.phase = .active
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(fixture.completions, 1)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(fixture.completions, 1)

        let cancelled = LaunchPresentationFixture()
        window.rootViewController = UIHostingController(rootView: LaunchPresentationHost(fixture: cancelled))
        try await Task.sleep(for: .milliseconds(100))
        cancelled.isReady = true
        try await Task.sleep(for: .milliseconds(100))
        window.rootViewController = nil
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(cancelled.completions, 0)
    }

    func testMountedSceneAcrossPhoneDuoAndPadSizes() async throws {
        let assets = try XCTUnwrap(N1LaunchAssets.load())
        let window = try host(N1LaunchScene(assets: assets, elapsed: 2, ignition: 0.28, liftProgress: 0)
            .ignoresSafeArea())
        defer { window.isHidden = true; window.rootViewController = nil }
        for size in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402),
                     CGSize(width: 466, height: 678), CGSize(width: 678, height: 466),
                     CGSize(width: 669, height: 951), CGSize(width: 951, height: 669),
                     CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
                     CGSize(width: 320, height: 900), CGSize(width: 500, height: 500),
                     CGSize(width: 1100, height: 320)] {
            window.frame.size = size
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            let view = try XCTUnwrap(window.rootViewController?.view)
            XCTAssertEqual(view.bounds.width, size.width, accuracy: 0.5)
            XCTAssertEqual(view.bounds.height, size.height, accuracy: 0.5)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "N1-wait-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func host<Content: View>(_ content: Content) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: content)
        window.makeKeyAndVisible()
        return window
    }
}

@MainActor @Observable
private final class LaunchPresentationFixture {
    var phase = ScenePhase.active
    var isReady = false
    var completions = 0
}

private struct LaunchPresentationHost: View {
    let fixture: LaunchPresentationFixture

    var body: some View {
        N1LoadingScreenView(isReady: fixture.isReady) { fixture.completions += 1 }
            .environment(\.scenePhase, fixture.phase)
    }
}
