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

@MainActor
@Test func metalModuleResourcesTransferOrbitFacadeDelegatesWithoutRenderer() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = MetalModuleResources()
    let transferOrbit = resources.transferOrbit

    #expect(ObjectIdentifier(transferOrbit) == ObjectIdentifier(resources))

    transferOrbit.showTransferOrbit(to: "Mars")
    transferOrbit.clearTransferOrbit()

    #expect(!resources.transferOrbitController.isTransferPreviewActive)
}
