import Foundation
import Testing
@testable import OptiUniverse

@MainActor
struct LegalCreditsTests {
    @Test func legalCreditsIncludeMilkyWayEnvironmentAttribution() throws {
        let section = try #require(
            LegalCreditsCatalog.sections.first { $0.title == "Milky Way Environment" }
        )
        let linksByTitle = Dictionary(uniqueKeysWithValues: section.links.map { ($0.title, $0.url.absoluteString) })

        #expect(section.body.contains("\"The Milky Way panorama\""))
        #expect(section.body.contains("ESO/S. Brunier"))
        #expect(section.body.contains("Creative Commons Attribution 4.0 International"))
        #expect(linksByTitle["Source"] == "https://www.eso.org/public/images/eso0932a/")
        #expect(linksByTitle["License"] == "https://creativecommons.org/licenses/by/4.0/")
        #expect(linksByTitle["ESO Usage Terms"] == "https://www.eso.org/public/outreach/copyright/")
    }

    @Test func thirdPartyNoticesIncludeMilkyWayEnvironmentAttribution() throws {
        let noticesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("THIRD_PARTY_NOTICES.md")
        let notices = try String(contentsOf: noticesURL, encoding: .utf8)

        #expect(notices.contains("## Milky Way Environment Texture"))
        #expect(notices.contains("The Milky Way panorama"))
        #expect(notices.contains("ESO/S. Brunier"))
        #expect(notices.contains("https://www.eso.org/public/images/eso0932a/"))
        #expect(notices.contains("Creative Commons Attribution 4.0 International"))
        #expect(notices.contains("https://creativecommons.org/licenses/by/4.0/"))
    }
}
