import BaseModule
import Foundation
import Metal
import Testing
@testable import UniverseModule

@MainActor
@Test func universeModuleResourcesNavigationFacadeIsObservableResource() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = UniverseModuleResources()
    let navigation = resources.navigation

    #expect(ObjectIdentifier(navigation) == ObjectIdentifier(resources))

    navigation.setNavigationCameraFollowEnabled(false)

    #expect(resources.navigationCameraFollowEnabled == false)
    #expect(navigation.navigationCameraFollowEnabled == false)
}

@MainActor
@Test func universeModuleResourcesTransferOrbitFacadeDelegatesWithoutRenderer() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = UniverseModuleResources()
    let transferOrbit = resources.transferOrbit

    #expect(ObjectIdentifier(transferOrbit) == ObjectIdentifier(resources))

    transferOrbit.showTransferOrbit(to: "Mars")
    transferOrbit.clearTransferOrbit()

    #expect(!resources.transferOrbitController.isTransferPreviewActive)
}

@MainActor
@Test func universeModuleResourcesResolvesSurfaceFollowTargetByDestinationID() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = UniverseModuleResources()
    let destinations = try decodeDestinationObjects("""
    [
      {
        "id": "BA41330B-C7FC-46B2-BAA9-E8CE85102A64",
        "object": "Moon",
        "title": "Moon Base",
        "subtitle": "First lunar outpost",
        "description": "A south pole surface destination.",
        "imageName": "dst-Moon_Base",
        "tag": "Base",
        "isNavigable": true,
        "surfaceLocation": {
          "latitudeDegrees": -90,
          "longitudeDegrees": 0
        },
        "details": [
          { "title": "Habitats", "value": "540", "dimension": "m3" }
        ]
      }
    ]
    """)
    let destination = try #require(destinations.first)

    let followTarget = try #require(resources.followTarget(for: destination.id,
                                                           destinations: destinations))
    let surfaceLocation = try #require(followTarget.surfaceLocation)

    #expect(followTarget.bodyName == "Moon")
    #expect(surfaceLocation.latitudeDegrees == -90)
    #expect(surfaceLocation.longitudeDegrees == 0)
}

@MainActor
@Test func universeModuleResourcesResolvesNonSurfaceFollowTargetByDestinationID() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = UniverseModuleResources()
    let destinations = try decodeDestinationObjects("""
    [
      {
        "id": "2530E63D-699E-4F38-9B77-EABDE51152A5",
        "object": "Mars",
        "title": "Mars",
        "subtitle": "Red Planet",
        "description": "Dusty world.",
        "imageName": "dst-Mars",
        "tag": "Hot",
        "isNavigable": true,
        "details": [
          { "title": "Age", "value": "4.5B", "dimension": "YEARS" }
        ]
      }
    ]
    """)
    let destination = try #require(destinations.first)

    let followTarget = try #require(resources.followTarget(for: destination.id,
                                                           destinations: destinations))

    #expect(followTarget.bodyName == "Mars")
    #expect(followTarget.surfaceLocation == nil)
    #expect(resources.followTarget(for: UUID(), destinations: destinations) == nil)
}

private func decodeDestinationObjects(_ json: String) throws -> [DestinationObject] {
    try JSONDecoder().decode([DestinationObject].self, from: Data(json.utf8))
}
