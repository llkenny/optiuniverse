import Testing
@testable import MetalModule

@Test func migrationControlsRenderEveryMetalSubsystemByDefault() {
    let controls = MetalSceneOwnershipControls.migration

    #expect(controls.renders(.environment))
    #expect(controls.renders(.starField))
    #expect(controls.rendersCelestialBody(named: "Earth"))
    #expect(controls.rendersCelestialBody(named: "Saturn"))
    #expect(controls.renders(.transferOrbit))
    #expect(controls.renders(.navigationRoute))
    #expect(controls.renders(.navigationMarker))
}

@Test func suppressingOneSubsystemDoesNotAffectOtherSubsystems() {
    let controls = MetalSceneOwnershipControls(
        suppressedSubsystems: [.environment, .celestialBody(named: "Earth")]
    )

    #expect(!controls.renders(.environment))
    #expect(controls.renders(.starField))
    #expect(!controls.rendersCelestialBody(named: "Earth"))
    #expect(controls.rendersCelestialBody(named: "Mars"))
    #expect(controls.renders(.transferOrbit))
}

@Test func suppressingUnknownBodyNameDoesNotAffectKnownBodies() {
    let controls = MetalSceneOwnershipControls(
        suppressedSubsystems: [.celestialBody(named: "Unknown")]
    )

    #expect(controls.rendersCelestialBody(named: "Earth"))
    #expect(controls.rendersCelestialBody(named: "Mars"))
}

@Test func navigationRouteAndMarkerCanBeSuppressedIndependently() {
    let routeSuppressed = MetalSceneOwnershipControls(
        suppressedSubsystems: [.navigationRoute]
    )
    let markerSuppressed = MetalSceneOwnershipControls(
        suppressedSubsystems: [.navigationMarker]
    )

    #expect(!routeSuppressed.renders(.navigationRoute))
    #expect(routeSuppressed.renders(.navigationMarker))
    #expect(markerSuppressed.renders(.navigationRoute))
    #expect(!markerSuppressed.renders(.navigationMarker))
}
