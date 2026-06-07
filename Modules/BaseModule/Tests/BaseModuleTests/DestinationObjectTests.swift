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
          { "title": "Age", "value": "4.5B", "dimension": "YEARS" },
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
    #expect(destination.details.map(\.title) == ["Age", "Diameter"])
    #expect(destination.surfaceLocation == nil)

    let orbitInfo = try #require(destination.orbitInfo)
    #expect(orbitInfo.description == "Mercury completes one orbit around the Sun every 88 days.")
    #expect(orbitInfo.properties.axis == "0.387 AU")
    #expect(orbitInfo.properties.eccentricity == "0.206")
    #expect(orbitInfo.properties.inclination == "7.00°")
}

@Test func destinationObjectDecodesSurfaceLocationPayload() throws {
    let destinations = try JSONDecoder().decode([DestinationObject].self, from: Data("""
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
    """.utf8))
    let destination = try #require(destinations.first)
    let surfaceLocation = try #require(destination.surfaceLocation)

    #expect(destination.object == "Moon")
    #expect(destination.title == "Moon Base")
    #expect(surfaceLocation.latitudeDegrees == -90)
    #expect(surfaceLocation.longitudeDegrees == 0)
}
