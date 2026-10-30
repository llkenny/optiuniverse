import CoreGraphics

/// Budgets include their controls so neither section pushes the other off screen.
nonisolated struct DiscoveryLayoutSizing {
    static let carouselPadding: CGFloat = 8
    static let indicatorHeight: CGFloat = 30
    static let sectionSpacing: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let destinationSpacing: CGFloat = 16

    let missionCardHeight: CGFloat
    let objectsHeight: CGFloat
    let destinationSide: CGFloat
    let destinationViewportHeight: CGFloat
    let needsPageScrolling: Bool

    init(availableHeight: CGFloat, minimumMissionCardHeight: CGFloat,
         categoryHeight: CGFloat, minimumDestinationSide: CGFloat,
         maximumDestinationSide: CGFloat = 174) {
        let height = Self.valid(availableHeight)
        let missionChrome = Self.carouselPadding * 2 + Self.indicatorHeight
        let objectChrome = Self.valid(categoryHeight) + Self.sectionSpacing + Self.bottomPadding
        let missionMinimum = Self.valid(minimumMissionCardHeight)
        let destinationMaximum = Self.valid(maximumDestinationSide)
        let destinationMinimum = min(destinationMaximum, Self.valid(minimumDestinationSide))
        let missionBudget = height * 2 / 3
        let objectsBudget = height / 3

        needsPageScrolling = missionMinimum + missionChrome > missionBudget ||
            destinationMinimum + objectChrome > objectsBudget
        missionCardHeight = max(missionMinimum, missionBudget - missionChrome)
        objectsHeight = max(destinationMinimum + objectChrome, objectsBudget)
        destinationViewportHeight = max(0, objectsHeight - objectChrome)
        destinationSide = min(destinationMaximum, max(destinationMinimum, destinationViewportHeight))
    }

    static func destinationColumnCount(availableWidth: CGFloat, cardSide: CGFloat) -> Int {
        guard availableWidth.isFinite, cardSide.isFinite, availableWidth > 0, cardSide > 0 else { return 1 }
        let count = ((availableWidth + destinationSpacing) / (cardSide + destinationSpacing)).rounded(.down)
        guard count.isFinite, count < CGFloat(Int.max) else { return 1 }
        return max(1, Int(count))
    }

    private static func valid(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }
}
