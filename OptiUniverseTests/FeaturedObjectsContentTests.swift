import BaseModule
import Foundation
import Testing
import UIKit

@MainActor
struct FeaturedObjectsContentTests {
    @Test func bundledFeaturedObjectsPreserveVersionOneContentContract() throws {
        let featuredObjects: [FeaturedObject] = try loadMainBundleJSON(named: "FeaturedObjects")
        let featuredNames = Set(featuredObjects.map(\.name))
        let ids = featuredObjects.map(\.id)

        #expect(featuredNames.contains("Saturn"))
        #expect(featuredNames.contains("Neptune"))
        #expect(featuredNames.contains("Mars"))
        #expect(Set(ids).count == ids.count)

        for featuredObject in featuredObjects {
            #expect(!featuredObject.name.isEmpty)
            #expect(!featuredObject.description.isEmpty)
            #expect(!featuredObject.imageName.isEmpty)
            #expect(!featuredObject.accentColor.isEmpty)
            #expect(UIImage(named: featuredObject.imageName) != nil)

            for color in featuredObject.accentColor {
                #expect((0...1).contains(color.red))
                #expect((0...1).contains(color.green))
                #expect((0...1).contains(color.blue))
            }
        }
    }
}
