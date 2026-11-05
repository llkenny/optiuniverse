import BaseModule
import Testing
@testable import OptiUniverse

@MainActor
struct ObjectInfoViewEntityTests {
    @Test func bundledDestinationsKeepTheirDetailsAndRouteAction() throws {
        let destinations: [DestinationObject] = try loadMainBundleJSON(named: "DestinationObjects")
        for destination in destinations {
            var routeCalls = 0
            let entity = ObjectInfoViewEntity(destination: destination) { routeCalls += 1 }
            #expect(entity.id == destination.id)
            #expect(entity.imageName == destination.infoImageName)
            #expect(entity.title == destination.title)
            #expect(entity.subtitle == destination.subtitle)
            #expect(entity.description == destination.description)
            #expect(entity.isNavigable == destination.isNavigable)
            #expect(entity.navigationButtonTitle == "🎯 Route")
            #expect(entity.details.count == destination.details.count)
            for (detail, source) in zip(entity.details, destination.details) {
                #expect(detail.title == source.title)
                #expect(detail.value == source.value)
                #expect(detail.dimension == source.dimension)
            }
            #expect(entity.orbitInfo?.description == destination.orbitInfo?.description)
            #expect(entity.orbitInfo?.properties[.axis] == destination.orbitInfo?.properties.axis)
            #expect(entity.orbitInfo?.properties[.eccentricity] == destination.orbitInfo?.properties.eccentricity)
            #expect(entity.orbitInfo?.properties[.inclination] == destination.orbitInfo?.properties.inclination)
            #expect(routeCalls == 0)
            entity.navigationButtonAction()
            #expect(routeCalls == 1)
        }
    }
}
