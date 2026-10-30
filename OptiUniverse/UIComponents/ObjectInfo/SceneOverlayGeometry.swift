import CoreGraphics

/// Both rectangles use the same container coordinate space, including the rendered safe-area extensions.
nonisolated struct SceneOverlayGeometry: Equatable {
    let sceneFrame: CGRect
    let panelFrame: CGRect

    var viewportHeight: CGFloat {
        isValid(sceneFrame) ? sceneFrame.height : 0
    }

    var bottomInset: CGFloat {
        guard isValid(sceneFrame), isValid(panelFrame), sceneFrame.intersects(panelFrame) else { return 0 }
        // Reserve everything below the panel's top, including the home-indicator region beneath it.
        return min(sceneFrame.height, max(0, sceneFrame.maxY - panelFrame.minY))
    }

    private func isValid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite &&
            [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite) &&
            frame.width > 0 && frame.height > 0
    }
}
