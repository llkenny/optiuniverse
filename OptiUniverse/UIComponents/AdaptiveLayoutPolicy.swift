import CoreGraphics

/// Content breakpoints use the space offered to the view, independent of the device or pose.
nonisolated enum AdaptiveLayoutPolicy {
    static func isExpandedDiscovery(width: CGFloat) -> Bool {
        width.isFinite && width >= 600
    }

    static func missionCardWidth(availableWidth: CGFloat) -> CGFloat {
        guard availableWidth.isFinite else { return 0 }
        return min(283, max(0, availableWidth - 32))
    }

    static func usesSidePanel(size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width >= 700 && size.height >= 400
    }

    static func sidePanelWidth(availableWidth: CGFloat) -> CGFloat {
        guard availableWidth.isFinite, availableWidth > 0 else { return 0 }
        return min(availableWidth, min(max(availableWidth * 0.4, 320), 380))
    }

    static func bottomPanelHeight(viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight.isFinite else { return 0 }
        return max(0, viewportHeight * 0.6)
    }
}
