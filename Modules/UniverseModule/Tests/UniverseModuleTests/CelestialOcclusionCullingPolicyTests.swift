import CoreGraphics
import RealityKit
import Testing
@testable import UniverseModule

@MainActor
@Test(arguments: [CelestialOcclusionCullingPolicy.systemDefault, .disabledForAtmosphericBodies])
func atmosphereCullingPolicyIsScopedToEarthAndVenus(policy: CelestialOcclusionCullingPolicy) throws {
    guard #available(iOS 27.0, visionOS 27.0, *) else { return }
    let resources = UniverseModuleResources()
    let coordinator = UniverseSceneCoordinator(
        planets: resources.planets,
        snapshotProvider: resources.snapshotProvider,
        cameraCoordinator: resources.cameraCoordinator,
        objectInfoOverlayFramingState: resources.objectInfoOverlayFramingState,
        navigationController: resources.navigationController,
        transferOrbitController: resources.transferOrbitController,
        assetRepository: resources.assetRepository,
        occlusionCullingPolicy: policy
    )
    coordinator.setViewportSize(CGSize(width: 390, height: 844))
    coordinator.update(deltaTime: 0.1)

    for (name, entities) in coordinator.bodyEntities {
        let component = entities.bodyRoot.components[OcclusionCullingComponent.self]
        if policy == .disabledForAtmosphericBodies && (name == "Earth" || name == "Venus") {
            #expect(try #require(component).isEnabled == false)
        } else {
            #expect(component == nil)
        }
        // Frame updates preserve the policy on the common ancestor of all asset layers.
        #expect(entities.visualRoot.parent == entities.rotationTransform)
        #expect(entities.rotationTransform.parent == entities.orbitTransform)
        #expect(entities.orbitTransform.parent == entities.bodyRoot)
    }
    #expect(coordinator.universeRoot.components[OcclusionCullingComponent.self] == nil)
    #expect(coordinator.celestialSystemRoot.components[OcclusionCullingComponent.self] == nil)
}

#if DEBUG
@Test func atmosphereCullingDiagnosticOverrideRequiresExplicitSystemValue() {
    #expect(CelestialOcclusionCullingPolicy.diagnosticPolicy(environment: [:]) == .disabledForAtmosphericBodies)
    #expect(CelestialOcclusionCullingPolicy.diagnosticPolicy(environment: [
        "OPTI_ATMOSPHERE_OCCLUSION_CULLING": "system"
    ]) == .systemDefault)
    #expect(CelestialOcclusionCullingPolicy.diagnosticPolicy(environment: [
        "OPTI_ATMOSPHERE_OCCLUSION_CULLING": "disabled"
    ]) == .disabledForAtmosphericBodies)
}
#endif
