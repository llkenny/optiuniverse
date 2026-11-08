#if os(iOS)
import SwiftUI

struct LaunchLoadingScreenView: View {
    let isReady: Bool
    var assetBundle: Bundle = .main
    // Internal dependencies keep slow decoding and motion changes reproducible in presentation tests.
    var assetLoader: @Sendable (Bundle) -> LaunchDioramaAssets? = { LaunchDioramaAssets.load(bundle: $0) }
    var motionOverride: Bool?
    let onCompletion: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sequence = LaunchSequence()
    @State private var assets: LaunchDioramaAssets?
    @State private var decodingTask: Task<LaunchDioramaAssets?, Never>?
    @State private var animationClock: LaunchAnimationClock?
    @AccessibilityFocusState private var loadingFocused: Bool
    @State private var frozenFrame: LaunchDioramaFrame?

    var body: some View {
        ZStack {
            if let assets {
                LaunchDioramaScene(assets: assets, frame: frozenFrame ?? currentFrame)
            } else {
                LaunchDioramaScene.background
                if shouldReduceMotion {
                    Text("Loading").foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .opacity(sequence.opacity)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityFocused($loadingFocused)
        .onAppear { loadingFocused = true }
        .task { await loadAssets() }
        .onChange(of: scenePhase, initial: true) { _, _ in updateClock() }
        .onChange(of: isReady) { _, _ in acceptReadiness() }
        .onChange(of: shouldReduceMotion, initial: true) { _, enabled in
            animationClock?.synchronize()
            if enabled {
                frozenFrame = currentFrame
                sequence.reduceMotionEnabled()
            } else if sequence.readyAt == nil {
                // Once the short fade starts, finish it without restarting flight or jumping backwards.
                frozenFrame = nil
            }
            updateClock()
        }
        .onDisappear {
            sequence.cancel()
            animationClock?.stop()
            animationClock = nil
            decodingTask?.cancel()
            decodingTask = nil
            assets = nil
        }
    }

    private var currentFrame: LaunchDioramaFrame {
        LaunchDioramaFrame(elapsed: sequence.elapsed, readyAt: sequence.readyAt,
                           liftProgress: sequence.liftProgress)
    }

    private var shouldReduceMotion: Bool { motionOverride ?? reduceMotion }

    private func loadAssets() async {
        sequence.reset()
        updateClock()
        assets = nil
        frozenFrame = shouldReduceMotion ? currentFrame : nil
        let bundle = assetBundle
        let loader = assetLoader
        let loading = Task.detached(priority: .userInitiated) { loader(bundle) }
        decodingTask = loading
        acceptReadiness()
        let decoded = await withTaskCancellationHandler {
            await loading.value
        } onCancel: {
            loading.cancel()
        }
        guard !Task.isCancelled, !loading.isCancelled else { return }
        decodingTask = nil
        assets = decoded
        acceptReadiness()
    }

    private func acceptReadiness() {
        guard isReady, sequence.readyAt == nil else { return }
        animationClock?.synchronize()
        // A late decorative image must never hold up an already prepared application.
        if assets == nil { decodingTask?.cancel() }
        sequence.resourcesReady(reduceMotion: shouldReduceMotion || assets == nil)
        updateClock()
    }

    private func updateClock() {
        guard scenePhase == .active, !sequence.isCancelled, sequence.phase != .completed,
              !shouldReduceMotion || sequence.readyAt != nil else {
            animationClock?.stop()
            return
        }
        if animationClock == nil {
            let sequence = sequence
            let completion = onCompletion
            animationClock = LaunchAnimationClock { delta in
                guard sequence.advance(by: delta) else { return false }
                completion()
                return true
            }
        }
        animationClock?.start()
    }
}
#endif
