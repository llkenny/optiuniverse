import Foundation
import Testing

@MainActor
struct AppStoreMetadataTests {
    @Test func appStoreMetadataMatchesVersionOneContract() throws {
        let info = try #require(Bundle.main.infoDictionary)

        #expect(info["CFBundleDisplayName"] as? String == "OptiUniverse")
        #expect(info["CFBundleIdentifier"] as? String == "my.OptiUniverse")
        #expect((info["CFBundleShortVersionString"] as? String)?.split(separator: ".").first == "1")
        #expect((info["CFBundleVersion"] as? String)?.isEmpty == false)
        #expect(info["LSApplicationCategoryType"] as? String == "public.app-category.education")
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }
}
