#if os(iOS)
import SwiftUI

struct LaunchDioramaScene: View {
    static let background = Color(red: 0.031, green: 0.046, blue: 0.074)

    let assets: LaunchDioramaAssets
    let frame: LaunchDioramaFrame

    var body: some View {
        Canvas { context, size in
            let layout = LaunchDioramaLayout(size: size)
            let diameter = layout.diameter
            halo(in: &context, center: layout.center, radius: diameter * 1.23,
                 tint: Color(red: 0.115, green: 0.168, blue: 0.243).opacity(0.64))
            // Add the weighted sprites within one layer so their identical deck stays fully opaque.
            context.drawLayer { pad in
                pad.blendMode = .plusLighter
                pad.opacity = 1 - frame.release
                pad.draw(image(assets.closedPad), in: layout.padRect)
                pad.opacity = frame.release
                pad.draw(image(assets.openPad), in: layout.padRect)
            }
            let ignition = frame.flameStrength
            let glowCenter = CGPoint(x: layout.engineOnPad.x, y: layout.engineOnPad.y + diameter * 0.06)
            halo(in: &context, center: glowCenter, radius: diameter * 0.31, verticalScale: 0.54,
                 tint: .orange.opacity(ignition * 0.32))
            smoke(in: context, layout: layout, foreground: false)
            if ignition > 0 {
                let pulse = 1 + 0.035 * sin(frame.time * 9)
                context.draw(image(assets.flame), in: layout.flameRect(liftProgress: frame.liftProgress,
                                                                     strength: ignition, pulse: pulse))
            }
            context.draw(image(assets.rocket), in: layout.rocketRect(liftProgress: frame.liftProgress))
            smoke(in: context, layout: layout, foreground: true)
        }
        .background(Self.background)
        .accessibilityHidden(true)
    }

    private func image(_ source: CGImage) -> Image {
        Image(decorative: source, scale: 1)
    }

    private func halo(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                      verticalScale: CGFloat = 1, tint: Color) {
        var glow = context
        glow.translateBy(x: center.x, y: center.y)
        glow.scaleBy(x: 1, y: verticalScale)
        let bounds = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
        glow.fill(Path(ellipseIn: bounds), with: .radialGradient(
            Gradient(colors: [tint, tint.opacity(0)]), center: .zero, startRadius: 0, endRadius: radius
        ))
    }

    private func smoke(in context: GraphicsContext, layout: LaunchDioramaLayout, foreground: Bool) {
        let activity = max(frame.flameStrength * 0.4, min(frame.liftProgress * 3, 1))
        let width = layout.diameter * (0.67 + 0.27 * activity)
        let height = width * 724 / 2172
        let drift = layout.diameter * 0.012 * sin(frame.time * 1.5)
        let breath = 1 + 0.025 * sin(frame.time * 2.1)
        var vapor = context
        vapor.opacity = foreground ? 0.19 + 0.15 * activity : 0.56 + 0.16 * activity
        let widthScale: CGFloat = foreground ? 0.94 : 1
        let heightScale: CGFloat = foreground ? 0.8 : 1
        let verticalOffset: CGFloat = foreground ? 0.20 : 0.47
        let bounds = CGRect(x: layout.center.x - width * widthScale / 2 + drift,
                            y: layout.engineOnPad.y - height * verticalOffset,
                            width: width * widthScale * breath, height: height * heightScale)
        vapor.draw(image(assets.smoke), in: bounds)
    }
}
#endif
