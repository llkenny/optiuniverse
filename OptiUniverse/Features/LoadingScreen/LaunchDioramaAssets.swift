#if os(iOS)
import CoreGraphics
import Foundation
import ImageIO
import os

/// Immutable decoded images can cross from the loading task to the main-actor scene.
nonisolated struct LaunchDioramaAssets: Sendable {
    let closedPad: CGImage
    let openPad: CGImage
    let rocket: CGImage
    let smoke: CGImage
    let flame: CGImage

    static func load(bundle: Bundle = .main) -> Self? {
        let interval = LaunchDiagnostics.signposter.beginInterval(
            "Diorama decoding", id: LaunchDiagnostics.signposter.makeSignpostID())
        defer { LaunchDiagnostics.signposter.endInterval("Diorama decoding", interval) }
        func image(_ suffix: String, limit: Int = 1024) -> CGImage? {
            guard !Task.isCancelled,
                  let url = bundle.url(forResource: "launch-diorama-\(suffix)", withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: limit,
                kCGImageSourceShouldCacheImmediately: true
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        guard let closedPad = image("pad-closed", limit: 1536), let openPad = image("pad-open", limit: 1536),
              let rocket = image("rocket"), let smoke = image("smoke"),
              let flame = image("flame") else { return nil }
        return Self(closedPad: closedPad, openPad: openPad, rocket: rocket, smoke: smoke, flame: flame)
    }
}
#endif
