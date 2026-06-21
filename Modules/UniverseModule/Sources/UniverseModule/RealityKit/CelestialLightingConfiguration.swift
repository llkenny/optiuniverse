import CoreGraphics
import RealityKit

@MainActor
enum CelestialLightingConfiguration {
    enum SunPointLight {
        static let entityName = "SunLight"
        static let color = CGColor(red: 1, green: 0.93, blue: 0.82, alpha: 1)
        static let intensity: Float = 2_000_000_000
        static let attenuationRadius: Float = 5_000
        static let attenuationFalloffExponent: Float = 2

        static var component: PointLightComponent {
            var component = PointLightComponent(cgColor: color,
                                                intensity: intensity,
                                                attenuationRadius: attenuationRadius)
            component.attenuationFalloffExponent = attenuationFalloffExponent
            return component
        }
    }
}
