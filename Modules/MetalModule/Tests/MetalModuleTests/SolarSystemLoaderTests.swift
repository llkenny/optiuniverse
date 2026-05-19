import Testing
@testable import MetalModule

@Test func solarSystemLoaderContainsVersionOneCanonicalBodies() {
    let planets = SolarSystemLoader.loadPlanets(from: "planets")
    let planetNames = Set(planets.map(\.name))
    let versionOneBodies = [
        "Sun",
        "Mercury",
        "Venus",
        "Earth",
        "Moon",
        "Mars",
        "Jupiter",
        "Saturn",
        "Uranus",
        "Neptune"
    ]

    for body in versionOneBodies {
        #expect(planetNames.contains(body))
    }
}

@Test func solarSystemLoaderScalesVersionOnePlanetData() throws {
    let planets = SolarSystemLoader.loadPlanets(from: "planets")
    let sun = try #require(planets.first { $0.name == "Sun" })
    let earth = try #require(planets.first { $0.name == "Earth" })
    let moon = try #require(planets.first { $0.name == "Moon" })

    for planet in planets {
        #expect(!planet.name.isEmpty)
        #expect(!planet.meshName.isEmpty)
        #expect(planet.radius > 0)
    }

    #expect(abs(sun.distance - 0) < 0.0001)
    #expect(abs(sun.radius - 0.696) < 0.0001)
    #expect(abs(earth.distance - 149.598) < 0.0001)
    #expect(abs(earth.radius - 0.006378) < 0.000001)
    #expect(moon.parentName == "Earth")
    #expect(abs(moon.distance - 0.3844) < 0.0001)
}
