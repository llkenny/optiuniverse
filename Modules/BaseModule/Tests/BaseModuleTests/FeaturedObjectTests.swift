import Foundation
import Testing
@testable import BaseModule

@Test func featuredObjectDecodesVersionOnePayload() throws {
    let featuredObjects = try JSONDecoder().decode([FeaturedObject].self, from: Data("""
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
      }
    ]
    """.utf8))
    let featuredObject = try #require(featuredObjects.first)

    #expect(featuredObject.name == "Saturn")
    #expect(featuredObject.description == "Ringed giant")
    #expect(featuredObject.imageName == "Saturn_3")
    #expect(featuredObject.accentColor.count == 2)
    #expect(featuredObject.accentColor.first?.red == 0.97)
}
