import CoreGraphics
import Testing
@testable import OptiUniverse

struct DiscoveryLayoutSizingTests {
    @Test func sectionsIncludeControlsInTheirHeightBudgets() {
        let sizing = DiscoveryLayoutSizing(availableHeight: 750, minimumMissionCardHeight: 240,
                                           categoryHeight: 44, minimumDestinationSide: 96)
        #expect(!sizing.needsPageScrolling)
        #expect(sizing.missionCardHeight + 46 == 500)
        #expect(sizing.objectsHeight == 250)
        #expect(sizing.destinationSide == 174)
    }

    @Test func compactCardsShrinkToKeepObjectsVisible() {
        let sizing = DiscoveryLayoutSizing(availableHeight: 600, minimumMissionCardHeight: 240,
                                           categoryHeight: 44, minimumDestinationSide: 96)
        #expect(!sizing.needsPageScrolling)
        #expect(sizing.destinationSide == 140)
        #expect(sizing.missionCardHeight + 46 + sizing.objectsHeight == 600)
    }

    @Test func shortWindowsAndLongTextEnableReadableScrolling() {
        let short = DiscoveryLayoutSizing(availableHeight: 300, minimumMissionCardHeight: 240,
                                          categoryHeight: 44, minimumDestinationSide: 96)
        #expect(short.needsPageScrolling)
        #expect(short.missionCardHeight == 240)
        #expect(short.objectsHeight == 156)
        let longText = DiscoveryLayoutSizing(availableHeight: 750, minimumMissionCardHeight: 600,
                                             categoryHeight: 80, minimumDestinationSide: 96)
        #expect(longText.needsPageScrolling)
        #expect(longText.missionCardHeight == 600)
    }

    @Test func unfoldedGridShrinksInsteadOfForcingPageScrolling() {
        let sizing = DiscoveryLayoutSizing(availableHeight: 600, minimumMissionCardHeight: 240,
                                           categoryHeight: 44, minimumDestinationSide: 96,
                                           maximumDestinationSide: 240)
        #expect(!sizing.needsPageScrolling)
        #expect(sizing.objectsHeight == 200)
        #expect(sizing.destinationSide == 140)
        #expect(sizing.destinationViewportHeight == 140)
    }

    @Test(arguments: [CGSize(width: 966, height: 592), CGSize(width: 600, height: 480),
                      CGSize(width: 700, height: 700), CGSize(width: 966, height: 900)])
    func unfoldedFirstRowAndColumnsStayInsideSafeContent(size: CGSize) {
        // Input is the safe content rectangle, after native bars and asymmetric edge insets.
        let sizing = DiscoveryLayoutSizing(availableHeight: size.height, minimumMissionCardHeight: 240,
                                           categoryHeight: 44, minimumDestinationSide: 96,
                                           maximumDestinationSide: 240)
        let width = size.width - DiscoveryLayoutSizing.horizontalPadding * 2
        let count = DiscoveryLayoutSizing.destinationColumnCount(availableWidth: width,
                                                                cardSide: sizing.destinationSide)
        let gridWidth = CGFloat(count) * sizing.destinationSide +
            CGFloat(count - 1) * DiscoveryLayoutSizing.destinationSpacing
        let firstRowBottom = sizing.missionCardHeight + 46 + 44 + 8 + sizing.destinationSide
        #expect(!sizing.needsPageScrolling)
        #expect(sizing.destinationSide <= sizing.destinationViewportHeight)
        #expect(firstRowBottom <= size.height - DiscoveryLayoutSizing.bottomPadding + 0.001)
        #expect(gridWidth <= width)
        #expect(abs(sizing.missionCardHeight + 46 + sizing.objectsHeight - size.height) < 0.001)
    }

    @Test func gridUsesWholeColumnsAndKeepsItsMaximumCardSize() {
        #expect(DiscoveryLayoutSizing.destinationColumnCount(availableWidth: 934, cardSide: 140) == 6)
        #expect(DiscoveryLayoutSizing.destinationColumnCount(availableWidth: 568, cardSide: 140) == 3)
        let sizing = DiscoveryLayoutSizing(availableHeight: 1_200, minimumMissionCardHeight: 240,
                                           categoryHeight: 44, minimumDestinationSide: 96,
                                           maximumDestinationSide: 240)
        #expect(sizing.destinationSide == 240)
    }

    @Test func expandedLayoutRetainsReadableFallbackForLargeText() {
        let sizing = DiscoveryLayoutSizing(availableHeight: 600, minimumMissionCardHeight: 600,
                                           categoryHeight: 80, minimumDestinationSide: 174,
                                           maximumDestinationSide: 240)
        #expect(sizing.needsPageScrolling)
        #expect(sizing.missionCardHeight == 600)
        #expect(sizing.destinationSide == 174)
    }

    @Test func scrollingSwitchesAtMeasuredMinimumWithoutLosingTheSplit() {
        let fits = DiscoveryLayoutSizing(availableHeight: 600, minimumMissionCardHeight: 354,
                                         categoryHeight: 44, minimumDestinationSide: 140)
        let overflows = DiscoveryLayoutSizing(availableHeight: 600, minimumMissionCardHeight: 355,
                                              categoryHeight: 44, minimumDestinationSide: 140)
        #expect(!fits.needsPageScrolling)
        #expect(overflows.needsPageScrolling)
    }

    @Test(arguments: [CGFloat.nan, .infinity, -.infinity, -1, 0])
    func transientGeometryProducesFiniteNonnegativeSizes(value: CGFloat) {
        let sizing = DiscoveryLayoutSizing(availableHeight: value, minimumMissionCardHeight: value,
                                           categoryHeight: value, minimumDestinationSide: value)
        #expect(sizing.missionCardHeight.isFinite && sizing.missionCardHeight >= 0)
        #expect(sizing.objectsHeight.isFinite && sizing.objectsHeight >= 0)
        #expect(sizing.destinationSide.isFinite && sizing.destinationSide >= 0)
        #expect(sizing.destinationViewportHeight.isFinite && sizing.destinationViewportHeight >= 0)
        #expect(DiscoveryLayoutSizing.destinationColumnCount(availableWidth: value, cardSide: 140) == 1)
        #expect(DiscoveryLayoutSizing.destinationColumnCount(availableWidth: 934, cardSide: value) == 1)
    }
}
