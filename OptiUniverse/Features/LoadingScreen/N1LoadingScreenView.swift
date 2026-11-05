#if os(iOS)
import SwiftUI
import UIKit

struct N1LoadingScreenView: View {
    let isReady: Bool
    let onCompletion: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sequence = LaunchSequence()
    @State private var assets: N1LaunchAssets?
    @State private var fallbackPhoto: UIImage?
    @State private var didLoadAssets = false

    var body: some View {
        ZStack {
            if let assets {
                N1LaunchScene(assets: assets, elapsed: sequence.elapsed,
                              ignition: reduceMotion ? 0 : sequence.ignition,
                              liftProgress: sequence.liftProgress)
            } else if let fallbackPhoto {
                Image(uiImage: fallbackPhoto).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OptiColor.screenBackground)
            } else {
                Color("N1LaunchSky")
                if !reduceMotion { ProgressView().tint(.white) }
            }
        }
        .opacity(sequence.opacity)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .task {
            assets = N1LaunchAssets.load()
            if assets == nil,
               let url = Bundle.main.url(forResource: "n1-original", withExtension: "jpg") {
                fallbackPhoto = UIImage(contentsOfFile: url.path)
            }
            didLoadAssets = true
            acceptReadiness()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(33))
                } catch { return }
                guard !Task.isCancelled else { return }
                let now = clock.now
                let duration = previous.duration(to: now).components
                previous = now
                // A static accessible waiting image doesn't need a per-frame view update.
                guard !reduceMotion || isReady else { continue }
                let delta = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                if sequence.advance(by: delta) {
                    onCompletion()
                    return
                }
            }
        }
        .onChange(of: isReady) { _, _ in acceptReadiness() }
        .onChange(of: reduceMotion, initial: true) { _, enabled in
            if enabled { sequence.reduceMotionEnabled() }
        }
        .onDisappear {
            sequence.cancel()
            assets = nil
            fallbackPhoto = nil
        }
    }

    private func acceptReadiness() {
        guard isReady, didLoadAssets else { return }
        sequence.resourcesReady(reduceMotion: reduceMotion || assets == nil)
    }
}

#if DEBUG
/// Also accessible with OPTI_LAUNCH_PREVIEW=1, without preparing the universe scene.
struct N1LaunchPreviewHost: View {
    @State private var isReady = false
    @State private var finished = false

    var body: some View {
        ZStack {
            OptiColor.screenBackground.ignoresSafeArea()
            if let sample = previewSample, let assets = N1LaunchAssets.load() {
                N1LaunchScene(assets: assets, elapsed: sample.elapsed,
                              ignition: sample.ignition, liftProgress: sample.liftProgress)
                    .ignoresSafeArea()
            } else if !finished {
                N1LoadingScreenView(isReady: isReady) { finished = true }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            isReady = true
        }
    }

    private var previewSample: LaunchSequence? {
        guard let value = ProcessInfo.processInfo.environment["OPTI_LAUNCH_PREVIEW_TIME"],
              let time = Double(value), time.isFinite, time >= 0 else { return nil }
        let sequence = LaunchSequence()
        sequence.advance(by: min(time, 3))
        if time >= 3 {
            sequence.resourcesReady(reduceMotion: false)
            sequence.advance(by: time - 3)
        }
        return sequence
    }
}

#Preview("N1 launch") {
    N1LaunchPreviewHost()
}
#endif
#endif
