import Foundation
import Testing
@testable import BaseModule

@Test func destinationObjectDecodesVersionOnePayload() throws {
    let destinations = try JSONDecoder().decode([DestinationObject].self, from: Data("""
    [
      {
        "id": "2F2B045C-4C7C-4797-A423-BAC3665F67AF",
        "object": "Mercury",
        "title": "Mercury",
        "subtitle": "Swift Cratered World",
        "description": "Closest planet to the Sun.",
        "imageName": "dst-Mercury",
        "tag": "Hot",
        "isNavigable": true,
        "details": [
          { "title": "Distance", "value": "0.39", "dimension": "AU" },
          { "title": "Diameter", "value": "4,879", "dimension": "KM" }
        ]
      }
    ]
    """.utf8))
    let destination = try #require(destinations.first)

    #expect(destination.object == "Mercury")
    #expect(destination.title == "Mercury")
    #expect(destination.subtitle == "Swift Cratered World")
    #expect(destination.description == "Closest planet to the Sun.")
    #expect(destination.imageName == "dst-Mercury")
    #expect(destination.tag == "Hot")
    #expect(destination.isNavigable)
    #expect(destination.details.map(\.title) == ["Distance", "Diameter"])
}
