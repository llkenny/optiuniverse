import SwiftUI

/// All photo layers share this transform; resizing never changes their relative alignment.
struct N1LaunchLayout {
    static let photoSize = CGSize(width: 916, height: 1500)

    let size: CGSize

    var scale: CGFloat {
        min(size.height * 0.9 / Self.photoSize.height, size.width / 600)
    }

    var photoSize: CGSize {
        CGSize(width: Self.photoSize.width * scale, height: Self.photoSize.height * scale)
    }

    var origin: CGPoint {
        CGPoint(x: engine.x - 320 * scale, y: engine.y - 1445 * scale)
    }

    var engine: CGPoint {
        let horizontal = size.width < size.height ? size.width * 0.45 : size.width / 2 - 118 * backgroundScale
        return CGPoint(x: horizontal, y: size.height - 17 * backgroundScale)
    }

    var backgroundScale: CGFloat {
        max(size.width / 1774, size.height / 887)
    }

    var backgroundSize: CGSize {
        CGSize(width: 1774 * backgroundScale, height: 887 * backgroundScale)
    }

    var backgroundOrigin: CGPoint {
        CGPoint(x: engine.x - 769 * backgroundScale, y: size.height - backgroundSize.height)
    }

    func point(x horizontal: CGFloat, y vertical: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + horizontal * scale, y: origin.y + vertical * scale)
    }

    func liftDistance(progress: Double) -> CGFloat {
        // Accelerate from rest. The nozzle clears the top edge at the end of the lift.
        (engine.y + size.height * 0.12) * CGFloat(progress * progress)
    }
}
