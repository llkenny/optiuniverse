#if os(iOS)
import SwiftUI
import UIKit

/// Loading from file avoids UIImage's process-wide named-image cache for this temporary scene.
struct N1LaunchAssets {
    let rocket: UIImage
    let surroundings: UIImage
    let vapor: UIImage
    let exhaust: UIImage

    static func load(bundle: Bundle = .main) -> Self? {
        func load(_ name: String, extension fileExtension: String = "png") -> UIImage? {
            guard let url = bundle.url(forResource: name, withExtension: fileExtension) else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
        guard let rocket = load("n1-rocket"),
              let surroundings = load("n1-surroundings"),
              let vapor = load("n1-vapor"),
              let exhaust = load("n1-exhaust") else { return nil }
        return Self(rocket: rocket, surroundings: surroundings, vapor: vapor, exhaust: exhaust)
    }
}

struct N1LaunchScene: View {
    let assets: N1LaunchAssets
    let elapsed: Double
    let ignition: Double
    let liftProgress: Double

    var body: some View {
        GeometryReader { geometry in
            let layout = N1LaunchLayout(size: geometry.size)
            let lift = layout.liftDistance(progress: liftProgress)
            ZStack(alignment: .topLeading) {
                surroundings(layout: layout)
                vapor(layout: layout, foreground: false)
                exhaust(layout: layout, lift: lift)
                photograph(assets.rocket, layout: layout)
                    .offset(y: -lift)
                vapor(layout: layout, foreground: true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.42), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: geometry.size.height * 0.2)
            }
        }
        .accessibilityHidden(true)
    }

    private func photograph(_ image: UIImage, layout: N1LaunchLayout) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: layout.photoSize.width, height: layout.photoSize.height)
            .position(x: layout.origin.x + layout.photoSize.width / 2,
                      y: layout.origin.y + layout.photoSize.height / 2)
    }

    private func surroundings(layout: N1LaunchLayout) -> some View {
        // One continuous plate avoids color and perspective seams between archival and outpainted sky.
        // Match its launch-pad anchor to the photo's engine anchor; only the rocket moves.
        return Image(uiImage: assets.surroundings)
            .resizable()
            .frame(width: layout.backgroundSize.width, height: layout.backgroundSize.height)
            .position(x: layout.backgroundOrigin.x + layout.backgroundSize.width / 2,
                      y: layout.backgroundOrigin.y + layout.backgroundSize.height / 2)
            .frame(width: layout.size.width, height: layout.size.height)
            .background(Color(red: 0.23, green: 0.42, blue: 0.55))
    }

    private func exhaust(layout: N1LaunchLayout, lift: CGFloat) -> some View {
        let width = 424 * layout.scale
        let height = max(70, 510 * layout.scale) * (0.45 + 0.55 * ignition)
        let nozzle = CGPoint(x: layout.engine.x, y: layout.engine.y - lift)
        return ZStack {
            Ellipse()
                .fill(.radialGradient(colors: [.orange.opacity(0.32), .clear],
                                      center: .center, startRadius: 0, endRadius: width * 0.9))
                .frame(width: width * 2, height: width)
                .position(x: layout.engine.x, y: layout.engine.y)
            Canvas { context, _ in
                let texture = context.resolve(Image(uiImage: assets.exhaust))
                // Overlapping jets form the broad skirt of the N1's engine cluster.
                for index in 0..<7 {
                    let horizontal = CGFloat(index) * 44 * layout.scale
                    let jetWidth = 160 * layout.scale
                    let jetHeight = height * (0.94 + 0.06 * sin(elapsed * 11 + Double(index) * 1.7))
                    var jet = context
                    jet.translateBy(x: horizontal + jetWidth / 2, y: 0)
                    jet.scaleBy(x: index.isMultiple(of: 2) ? 1 : -1, y: 1)
                    jet.draw(texture, in: CGRect(x: -jetWidth / 2, y: 0,
                                                 width: jetWidth, height: jetHeight))
                }
            }
                .frame(width: width, height: height)
                .distortionEffect(
                    ShaderLibrary.n1Exhaust(.float(elapsed), .float2(width, height)),
                    maxSampleOffset: CGSize(width: 4, height: 0)
                )
                .position(x: nozzle.x, y: nozzle.y + height / 2 - 8 * layout.scale)
        }
        .opacity(ignition)
    }

    private func vapor(layout: N1LaunchLayout, foreground: Bool) -> some View {
        N1VaporCanvas(image: Image(uiImage: assets.vapor), elapsed: elapsed,
                      ignition: ignition, liftProgress: liftProgress, layout: layout,
                      foreground: foreground)
    }
}

private struct N1VaporCanvas: View {
    let image: Image
    let elapsed: Double
    let ignition: Double
    let liftProgress: Double
    let layout: N1LaunchLayout
    let foreground: Bool

    var body: some View {
        Canvas { context, _ in
            guard ignition > 0 else { return }
            let texture = context.resolve(image)
            // Bounded, deterministic particles keep startup memory and CPU independent of loading duration.
            for index in 0..<16 {
                let seed = Double(index)
                let age = (elapsed * 0.21 + seed * 0.137).truncatingRemainder(dividingBy: 1)
                let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                let spread = CGFloat(age) * (foreground ? 540 : 350) * layout.scale
                let width = (95 + CGFloat(age) * 400) * layout.scale
                let center = CGPoint(x: layout.engine.x + direction * spread,
                                     y: layout.engine.y - CGFloat(age) * 145 * layout.scale)
                let fade = sin(age * .pi) * (foreground ? 0.3 : 0.24)
                var particle = context
                particle.opacity = fade * ignition * (1 - liftProgress * 0.4)
                particle.translateBy(x: center.x, y: center.y)
                particle.rotate(by: .degrees(direction * CGFloat(seed * 3 + age * 12)))
                particle.draw(texture, in: CGRect(x: -width / 2, y: -width * 0.33,
                                                  width: width, height: width * 0.66))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
#endif
