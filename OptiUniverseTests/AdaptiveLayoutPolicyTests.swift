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
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(viewportHeight: 500) == 300)
    }

    @Test(arguments: [CGFloat.nan, .infinity, -.infinity, -1, 0])
    func invalidGeometryCannotProduceInvalidLayout(value: CGFloat) {
        #expect(!AdaptiveLayoutPolicy.isExpandedDiscovery(width: value))
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: value, height: 400)))
        #expect(!AdaptiveLayoutPolicy.usesSidePanel(size: CGSize(width: 700, height: value)))
        #expect(AdaptiveLayoutPolicy.missionCardWidth(availableWidth: value) == 0)
        #expect(AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: value) == 0)
        #expect(AdaptiveLayoutPolicy.bottomPanelHeight(viewportHeight: value) == 0)
    }
}
