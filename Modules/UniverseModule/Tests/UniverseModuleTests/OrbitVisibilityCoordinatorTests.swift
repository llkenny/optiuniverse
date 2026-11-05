import Testing
@testable import UniverseModule

@MainActor
@Test func coordinatorPreservesOrbitVisibilityAcrossPreparationAndReinstallation() async throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    #expect(!coordinator.areOrbitLinesVisible)
    #expect(!coordinator.orbitLinesRoot.isEnabled)

    resources.setOrbitLinesVisible(true)
    try await resources.prepare()
    let content = try #require(coordinator.proceduralSceneContent)
    #expect(coordinator.orbitLinesRoot.isEnabled)
    #expect(content.orbitLines.root.isEnabled)

    content.transferEarthOrbit.entity.isEnabled = true
    content.transferDestinationOrbit.entity.isEnabled = true
    content.transferPath.entity.isEnabled = true
    content.navigationPath.entity.isEnabled = true
    resources.setOrbitLinesVisible(false)
    #expect(!coordinator.areOrbitLinesVisible)
    #expect(!coordinator.orbitLinesRoot.isEnabled)
    #expect(!content.orbitLines.root.isEnabled)
    #expect(content.transferEarthOrbit.entity.isEnabled)
    #expect(content.transferDestinationOrbit.entity.isEnabled)
    #expect(content.transferPath.entity.isEnabled)
    #expect(content.navigationPath.entity.isEnabled)

    coordinator.install(proceduralSceneContent: content)
    #expect(!content.orbitLines.root.isEnabled)
    resources.setOrbitLinesVisible(true)
    coordinator.install(proceduralSceneContent: content)
    #expect(coordinator.orbitLinesRoot.isEnabled)
    #expect(content.orbitLines.root.isEnabled)
    #expect(coordinator.orbitLinesRoot.children.count == 1)
}
