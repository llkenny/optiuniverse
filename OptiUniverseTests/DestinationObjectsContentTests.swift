import BaseModule
import Foundation
import Testing
import UIKit

@MainActor
struct DestinationObjectsContentTests {
    @Test func bundledDestinationsPreserveVersionOneContentContract() throws {
        let destinations: [DestinationObject] = try loadMainBundleJSON(named: "DestinationObjects")
        let destinationNames = Set(destinations.map(\.title))
        let ids = destinations.map(\.id)

        for destinationName in v1DestinationNames {
            #expect(destinationNames.contains(destinationName))
        }

        #expect(Set(ids).count == ids.count)

        for destination in destinations where v1DestinationNames.contains(destination.title) {
            #expect(!destination.object.isEmpty)
            #expect(!destination.title.isEmpty)
            #expect(!destination.subtitle.isEmpty)
            #expect(!destination.description.isEmpty)
            #expect(!destination.imageName.isEmpty)
            #expect(!destination.tag.isEmpty)
            #expect(!destination.details.isEmpty)
            #expect(UIImage(named: destination.imageName) != nil)

            let detailTitles = Set(destination.details.map(\.title))
            #expect(detailTitles.contains("Age"))
            #expect(detailTitles.contains("Diameter"))
            #expect(detailTitles.contains("Mass"))
            #expect(detailTitles.contains("Surface temp"))

            for detail in destination.details {
                #expect(!detail.title.isEmpty)
                #expect(!detail.value.isEmpty)
                #expect(!detail.dimension.isEmpty)
            }
        }

        let nonNavigableV1Objects = ["Sun", "Earth", "Moon"]
        for destination in destinations where v1DestinationNames.contains(destination.title) {
            #expect(destination.isNavigable == !nonNavigableV1Objects.contains(destination.title))
        }
    }

    @Test func bundledMoonBaseDestinationCarriesSurfaceLocation() throws {
        let destinations: [DestinationObject] = try loadMainBundleJSON(named: "DestinationObjects")
        let moonBase = try #require(destinations.first { $0.title == "Moon Base" })
        let surfaceLocation = try #require(moonBase.surfaceLocation)

        #expect(moonBase.object == "Moon")
        #expect(surfaceLocation.latitudeDegrees == -90)
        #expect(surfaceLocation.longitudeDegrees == 0)
    }
}
