#if DEBUG && os(iOS)
import SwiftUI

struct LaunchDioramaPreviewHost: View {
    @State private var assets: LaunchDioramaAssets?
    @State private var isReady = false
    @State private var finished = false

    var body: some View {
        ZStack {
            LaunchDioramaScene.background.ignoresSafeArea()
            if let sample = previewSample {
                if let assets {
                    LaunchDioramaScene(assets: assets, frame: sample).ignoresSafeArea()
                }
            } else if !finished {
                LaunchLoadingScreenView(isReady: isReady) { finished = true }
            }
        }
        .task {
            if previewSample != nil {
                assets = await Task.detached { LaunchDioramaAssets.load() }.value
                return
            }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch { return }
            isReady = true
        }
    }

    private var previewSample: LaunchDioramaFrame? {
        guard let value = ProcessInfo.processInfo.environment["OPTI_LAUNCH_PREVIEW_TIME"],
              let time = Double(value), time.isFinite, time >= 0 else { return nil }
        let sequence = LaunchSequence()
        sequence.advance(by: min(time, 3))
        if time >= 3 {
            sequence.resourcesReady(reduceMotion: false)
            sequence.advance(by: time - 3)
        }
        return LaunchDioramaFrame(elapsed: sequence.elapsed, readyAt: sequence.readyAt,
                                  liftProgress: sequence.liftProgress)
    }
}

#Preview("iPhone launch diorama") {
    LaunchDioramaPreviewHost()
}
#endif
