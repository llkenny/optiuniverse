import Foundation
import OSLog
import RealityKit

enum CelestialOcclusionCullingPolicy: Equatable {
    case systemDefault
    case disabledForAtmosphericBodies

    static var current: Self {
        #if DEBUG
        diagnosticPolicy(environment: ProcessInfo.processInfo.environment)
        #else
        .disabledForAtmosphericBodies
        #endif
    }

    #if DEBUG
    /// Set this environment variable to `system` in the Xcode Run action for the baseline.
    static func diagnosticPolicy(environment: [String: String]) -> Self {
        environment["OPTI_ATMOSPHERE_OCCLUSION_CULLING"] == "system"
            ? .systemDefault : .disabledForAtmosphericBodies
    }
    #endif

    @MainActor
    func apply(to bodyRoot: Entity, bodyName: String) {
        guard bodyName == "Earth" || bodyName == "Venus",
              #available(iOS 27.0, visionOS 27.0, *) else { return }

        // Nested transparent shells can cause incorrect occlusion decisions while the
        // camera or the rebased scene moves. The component is inherited by all layers.
        if self == .disabledForAtmosphericBodies {
            bodyRoot.components.set(OcclusionCullingComponent(isEnabled: false))
        }

        #if DEBUG
        let mode = self == .systemDefault ? "system" : "disabled"
        Logger(subsystem: "OptiUniverse.UniverseModule", category: "AtmosphereRendering")
            .info("Atmosphere occlusion culling body=\(bodyName, privacy: .public) mode=\(mode, privacy: .public)")
        #endif
    }
}
