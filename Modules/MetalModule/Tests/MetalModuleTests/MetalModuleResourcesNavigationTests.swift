import Metal
import Testing
@testable import MetalModule

@MainActor
@Test func metalModuleResourcesNavigationFacadeIsObservableResource() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = MetalModuleResources()
    let navigation = resources.navigation

    #expect(ObjectIdentifier(navigation) == ObjectIdentifier(resources))

    navigation.setNavigationCameraFollowEnabled(false)

    #expect(resources.navigationCameraFollowEnabled == false)
    #expect(navigation.navigationCameraFollowEnabled == false)
}
