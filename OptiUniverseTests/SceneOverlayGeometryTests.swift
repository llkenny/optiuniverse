import CoreGraphics
import Testing
@testable import OptiUniverse

struct SceneOverlayGeometryTests {
    @Test func expandedViewportIncludesRegionBelowSafeAreaPanel() {
        let geometry = SceneOverlayGeometry(sceneFrame: CGRect(x: -20, y: -60, width: 440, height: 900),
                                            panelFrame: CGRect(x: 0, y: 450, width: 380, height: 350))
        #expect(geometry.viewportHeight == 900)
        #expect(geometry.bottomInset == 390)
    }

    @Test func unchangedPanelReframesWhenSceneExpands() {
        let panel = CGRect(x: 0, y: 450, width: 380, height: 350)
        let safe = SceneOverlayGeometry(sceneFrame: CGRect(x: 0, y: 0, width: 380, height: 800), panelFrame: panel)
        let expanded = SceneOverlayGeometry(sceneFrame: CGRect(x: 0, y: -60, width: 440, height: 900),
                                           panelFrame: panel)
        #expect(safe.bottomInset == 350)
        #expect(expanded.bottomInset == 390)
        #expect(expanded.bottomInset / expanded.viewportHeight != safe.bottomInset / safe.viewportHeight)
    }

    @Test func movingPanelUsesPositionRatherThanHeight() {
        let scene = CGRect(x: 0, y: -60, width: 440, height: 900)
        let original = SceneOverlayGeometry(sceneFrame: scene,
                                            panelFrame: CGRect(x: 0, y: 450, width: 380, height: 350))
        let moved = SceneOverlayGeometry(sceneFrame: scene, panelFrame: CGRect(x: 0, y: 550, width: 380, height: 350))
        #expect(original.bottomInset - moved.bottomInset == 100)
    }

    @Test func reservedSidePanelDoesNotCoverScene() {
        let geometry = SceneOverlayGeometry(sceneFrame: CGRect(x: -20, y: -60, width: 600, height: 900),
                                            panelFrame: CGRect(x: 600, y: 0, width: 320, height: 800))
        #expect(geometry.bottomInset == 0)
    }

    @Test func missingAndInvalidFramesDoNotProduceCoverage() {
        let scene = CGRect(x: 0, y: 0, width: 390, height: 844)
        for invalid in [CGRect.zero, .null, .infinite, CGRect(x: 0, y: 0, width: CGFloat.nan, height: 400)] {
            #expect(SceneOverlayGeometry(sceneFrame: scene, panelFrame: invalid).bottomInset == 0)
            #expect(SceneOverlayGeometry(sceneFrame: invalid, panelFrame: scene).viewportHeight == 0)
        }
        let covering = SceneOverlayGeometry(sceneFrame: scene,
                                            panelFrame: CGRect(x: 0, y: -100, width: 390, height: 1_000))
        #expect(covering.bottomInset == scene.height)
    }
}
