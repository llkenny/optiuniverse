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
        ],
        "orbitInfo": {
          "description": "Mercury completes one orbit around the Sun every 88 days.",
          "properties": {
            "axis": "0.387 AU",
            "eccentricity": "0.206",
            "inclination": "7.00°"
          }
        }
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

    let orbitInfo = try #require(destination.orbitInfo)
    #expect(orbitInfo.description == "Mercury completes one orbit around the Sun every 88 days.")
    #expect(orbitInfo.properties.axis == "0.387 AU")
    #expect(orbitInfo.properties.eccentricity == "0.206")
    #expect(orbitInfo.properties.inclination == "7.00°")
}
