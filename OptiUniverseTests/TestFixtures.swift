import BaseModule
import Foundation

let v1DestinationNames = [
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

func loadMainBundleJSON<T: Decodable>(named filename: String) throws -> [T] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
        throw FixtureError.missingResource(filename)
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([T].self, from: data)
}

func isHomeScreen(_ screen: AppEnvironment.Screen) -> Bool {
    if case .home = screen {
        return true
    }

    return false
}

func decodeFeaturedObjectsFixture() throws -> [FeaturedObject] {
    try JSONDecoder().decode([FeaturedObject].self, from: Data("""
    [
      {
        "id": "0E40ED4E-A635-41D3-974B-32C1FD2225DB",
        "name": "Saturn",
        "description": "Ringed giant",
        "imageName": "Saturn_3",
        "accentColor": [
          { "red": 0.97, "green": 0.72, "blue": 0.42 },
          { "red": 0.34, "green": 0.16, "blue": 0.08 }
        ]
      },
      {
        "id": "83855A92-302D-46E5-87BC-A0DBA6748EF7",
        "name": "Neptune",
        "description": "Deep blue frontier",
        "imageName": "Neptune_1",
        "accentColor": [
          { "red": 0.28, "green": 0.57, "blue": 0.98 }
        ]
      },
      {
        "id": "E2232F82-868D-4F95-9BC8-CEFE50999A0E",
        "name": "Mars",
        "description": "Red world",
        "imageName": "Mars_1",
        "accentColor": [
          { "red": 0.93, "green": 0.45, "blue": 0.28 }
        ]
      }
    ]
    """.utf8))
}

func decodeDestinationsFixture() throws -> [DestinationObject] {
    try JSONDecoder().decode([DestinationObject].self, from: Data("""
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
          { "title": "Age", "value": "4.5B", "dimension": "YEARS" }
        ]
      },
      {
        "id": "C8D6C926-C315-45FC-8916-4A1457CEB94F",
        "object": "Earth",
        "title": "Earth",
        "subtitle": "Blue Home World",
        "description": "Known living world.",
        "imageName": "dst-Earth",
        "tag": "Inhabited",
        "isNavigable": false,
        "details": [
          { "title": "Age", "value": "4.5B", "dimension": "YEARS" }
        ]
      },
      {
        "id": "E2232F82-868D-4F95-9BC8-CEFE50999A0E",
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
    """.utf8))
}

private enum FixtureError: Error {
    case missingResource(String)
}

actor MockFeaturedObjectProvider: FeaturedObjectProviderProtocol {
    let featuredObjects: [FeaturedObject]

    init(featuredObjects: [FeaturedObject]) {
        self.featuredObjects = featuredObjects
    }

    func fetch() async {
    }
}

actor MockDestinationsProvider: DestinationsProviderProtocol {
    let destinations: [DestinationObject]

    init(destinations: [DestinationObject]) {
        self.destinations = destinations
    }

    func fetch() async {
    }
}
