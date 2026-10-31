import CoreGraphics
import Testing
@testable import OptiUniverse

struct AdaptiveLayoutPolicyTests {
    @Test func discoveryChangesAtContentBreakpoint() {
        #expect(!AdaptiveLayoutPolicy.isExpandedDiscovery(width: 599))
        #expect(AdaptiveLayoutPolicy.isExpandedDiscovery(width: 600))
    }

    @Test func sidePanelRequiresBothDimensions() {
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: 699, height: 400)))
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: 700, height: 399)))
        #expect(AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: 700, height: 400)))
    }

    @Test func missionCardsFitNarrowWindowsAndKeepDesignedMaximum() {
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: 200) == 168)
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: 315) == 283)
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: 1_000) == 283)
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: 20) == 0)
    }

    @Test func panelBoundsPreserveSceneSpace() {
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: 700) == 320)
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: 900) == 360)
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: 1_200) == 380)
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: 200) == 200)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 300, viewportHeight: 500) == 300)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 700, viewportHeight: 500) == 500)
    }

    @Test func bottomOverlayUsesItsNaturalHeightInsteadOfAHeightFraction() {
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 480, viewportHeight: 700) == 480)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 480, viewportHeight: 250) == 250)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 0, viewportHeight: 700) == 0)
    }

    @Test(arguments: [CGFloat(320), 350, 375, 380, 393, 402])
    func supportedInfoWidthsKeepFourStatisticsAndHorizontalOrbit(width: CGFloat) {
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: width, isAccessibilitySize: false) == 4)
        #expect(AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: width - 32, isAccessibilitySize: false))
    }

    @Test func minimumSidePanelKeepsDesignedInfoRows() {
        let width = AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: 700)
        #expect(width == 320)
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: width, isAccessibilitySize: false) == 4)
        #expect(AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: width - 32, isAccessibilitySize: false))
    }

    @Test func infoContentAdaptsAtItsOwnWidthBreakpoints() {
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: 319, isAccessibilitySize: false) == 2)
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: 320, isAccessibilitySize: false) == 4)
        #expect(!AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: 287, isAccessibilitySize: false))
        #expect(AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: 288, isAccessibilitySize: false))
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: 700, isAccessibilitySize: true) == 1)
        #expect(!AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: 700, isAccessibilitySize: true))
    }

    @Test(arguments: [CGFloat.nan, .infinity, -.infinity, -1, 0])
    func invalidGeometryCannotProduceInvalidLayout(value: CGFloat) {
        #expect(!AdaptiveLayoutPolicy.isExpandedDiscovery(width: value))
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: value, height: 400)))
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: 700, height: value)))
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: value) == 0)
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: value) == 0)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: 300, viewportHeight: value) == 0)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(contentHeight: value, viewportHeight: 500) == 0)
        #expect(AdaptiveLayoutPolicy.infoDetailColumnCount(availableWidth: value, isAccessibilitySize: false) == 1)
        #expect(!AdaptiveLayoutPolicy.usesHorizontalInfoOrbit(cardWidth: value, isAccessibilitySize: false))
    }
}
