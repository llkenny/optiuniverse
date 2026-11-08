import Observation
import SwiftUI
import XCTest
@testable import OptiUniverse

@MainActor
final class LaunchPresentationTests: XCTestCase {
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

    func testDioramaSceneAcrossDevicesAndWindows() async throws {
        let assets = try XCTUnwrap(LaunchDioramaAssets.load())
        let samples = [
            ("waiting", LaunchDioramaFrame(elapsed: 0.3, readyAt: nil, liftProgress: 0)),
            ("ignition", LaunchDioramaFrame(elapsed: 2, readyAt: nil, liftProgress: 0)),
            ("ascent", LaunchDioramaFrame(elapsed: 4.1, readyAt: 3, liftProgress: 0.76))
        ]
        let window = try host(Color.clear)
        defer { window.isHidden = true; window.rootViewController = nil }
        for size in LaunchReviewSizes.all {
            window.frame.size = size
            for (name, frame) in samples {
                window.rootViewController = UIHostingController(
                    rootView: LaunchDioramaScene(assets: assets, frame: frame).ignoresSafeArea())
                window.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                let view = try XCTUnwrap(window.rootViewController?.view)
                XCTAssertEqual(view.bounds.width, size.width, accuracy: 0.5)
                XCTAssertEqual(view.bounds.height, size.height, accuracy: 0.5)
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Diorama-\(name)-\(Int(size.width))x\(Int(size.height))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testMissingDioramaImagesStillComplete() async throws {
        var completions = 0
        let window = try host(LaunchLoadingScreenView(isReady: true, assetBundle: Bundle(for: Self.self)) {
            completions += 1
        }.environment(\.scenePhase, .active))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(completions, 1)
    }

    func testSlowDecodingCannotDelayReadyApplication() async throws {
        var completions = 0
        let window = try host(LaunchLoadingScreenView(isReady: true, assetLoader: { _ in
            Thread.sleep(forTimeInterval: 0.8)
            return LaunchDioramaAssets.load()
        }, onCompletion: { completions += 1 }).environment(\.scenePhase, .active))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(completions, 1)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(completions, 1)
    }

    func testMotionChangesDuringFlightFinishWithoutRestarting() async throws {
        let fixture = LaunchPresentationFixture()
        let window = try host(LaunchPresentationHost(fixture: fixture))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(200))
        fixture.isReady = true
        try await Task.sleep(for: .milliseconds(450))
        fixture.reduceMotion = true
        try await Task.sleep(for: .milliseconds(50))
        fixture.reduceMotion = false
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(fixture.completions, 1)
    }

    func testBackgroundPausesEveryFinishingPhase() async throws {
        for delay in [0.05, 0.6, 1.48] {
            let fixture = LaunchPresentationFixture()
            let window = try host(LaunchPresentationHost(fixture: fixture))
            try await Task.sleep(for: .milliseconds(200))
            fixture.isReady = true
            try await Task.sleep(for: .seconds(delay))
            fixture.phase = .background
            try await Task.sleep(for: .milliseconds(500))
            XCTAssertEqual(fixture.completions, 0, "Background at \(delay)")
            fixture.phase = .active
            try await Task.sleep(for: .seconds(2))
            XCTAssertEqual(fixture.completions, 1)
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    func testResizingDuringFlightPreservesSequenceAndSingleCompletion() async throws {
        let fixture = LaunchPresentationFixture()
        let window = try host(LaunchPresentationHost(fixture: fixture))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(200))
        fixture.isReady = true
        for size in [CGSize(width: 466, height: 678), CGSize(width: 951, height: 669),
                     CGSize(width: 320, height: 900), CGSize(width: 1100, height: 320)] {
            window.frame.size = size
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(fixture.completions, 0)
        }
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(fixture.completions, 1)
    }

    func testFailureCancelsFlightAndRetryWaitsForFreshReadiness() async throws {
        let fixture = LaunchPresentationFixture()
        let window = try host(LaunchPresentationHost(fixture: fixture))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(200))
        fixture.isReady = true
        try await Task.sleep(for: .milliseconds(100))
        fixture.showsLoading = false
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(fixture.completions, 0)
        fixture.isReady = false
        fixture.attempt += 1
        fixture.showsLoading = true
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(fixture.completions, 0)
        fixture.isReady = true
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(fixture.completions, 1)
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
    var reduceMotion = false
    var showsLoading = true
    var attempt = 0
    var completions = 0
}

private struct LaunchPresentationHost: View {
    let fixture: LaunchPresentationFixture

    var body: some View {
        Group {
            if fixture.showsLoading {
                LaunchLoadingScreenView(isReady: fixture.isReady, motionOverride: fixture.reduceMotion) {
                    fixture.completions += 1
                }.id(fixture.attempt)
            } else {
                Text("Unable to Load Universe")
            }
        }
        .environment(\.scenePhase, fixture.phase)
    }
}
