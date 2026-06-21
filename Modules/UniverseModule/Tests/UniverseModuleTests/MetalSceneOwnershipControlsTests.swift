import Testing
@testable import UniverseModule

@Test func migrationControlsSuppressOnlyRealityKitOwnedBodies() {
    let controls = MetalSceneOwnershipControls.migration(
        realityKitBodyNames: ["Sun", "Neptune"]
    )

    #expect(controls.renders(.environment))
    #expect(controls.renders(.starField))
    #expect(!controls.rendersCelestialBody(named: "Sun"))
    #expect(!controls.rendersCelestialBody(named: "Neptune"))
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

@Test func completedStageFourSuppressesEveryMigratedVisibleSubsystem() {
    let controls = MetalSceneOwnershipControls.migration(
        realityKitBodyNames: ["Sun", "Earth"],
        stageFourContentPrepared: true
    )

    #expect(!controls.renders(.environment))
    #expect(!controls.renders(.starField))
    #expect(!controls.renders(.transferOrbit))
    #expect(!controls.renders(.navigationRoute))
    #expect(!controls.renders(.navigationMarker))
    #expect(!controls.rendersCelestialBody(named: "Sun"))
    #expect(!controls.rendersCelestialBody(named: "Earth"))
}
