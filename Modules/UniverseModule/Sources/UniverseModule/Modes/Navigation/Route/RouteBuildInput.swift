import Foundation
import simd

/// Immutable input bundle for route path construction.
///
/// The builder needs positions and planet metadata from a prepared scene snapshot, but it should not own
/// that snapshot or reach back into render systems. This value defines the complete data dependency for
/// route geometry creation.
struct RouteBuildInput {
    let originName: String
    let waypointName: String?
    let destinationName: String
    let planets: [Planet]
    let originPosition: SIMD3<Float>?
    let waypointPosition: SIMD3<Float>?
    let originSurfaceRadius: Float
    let waypointSurfaceRadius: Float
    let destinationSurfaceRadius: Float
    let earthSunDirection: SIMD3<Float>
    let sunPosition: SIMD3<Float>
    let destinationPosition: SIMD3<Float>?
    let estimatedDuration: TimeInterval
    var transfer: TransferSolution?
    let simulationTime: Double
    let routeProgress: Float
    let stateProvider: (any CelestialStateProviding)?

    init(originName: String = "Earth",
         waypointName: String? = nil,
         destinationName: String,
         planets: [Planet],
         originPosition: SIMD3<Float>? = nil,
         waypointPosition: SIMD3<Float>? = nil,
         originSurfaceRadius: Float = 0,
         waypointSurfaceRadius: Float = 0,
         destinationSurfaceRadius: Float = 0,
         earthSunDirection: SIMD3<Float>,
         sunPosition: SIMD3<Float>,
         destinationPosition: SIMD3<Float>?,
         estimatedDuration: TimeInterval,
         simulationTime: Double = 0,
         transfer: TransferSolution? = nil,
         stateProvider: (any CelestialStateProviding)? = nil,
         routeProgress: Float = 0) {
        self.originName = originName
        self.waypointName = waypointName
        self.destinationName = destinationName
        self.planets = planets
        self.originPosition = originPosition
        self.waypointPosition = waypointPosition
        self.originSurfaceRadius = originSurfaceRadius
        self.waypointSurfaceRadius = waypointSurfaceRadius
        self.destinationSurfaceRadius = destinationSurfaceRadius
        self.earthSunDirection = earthSunDirection
        self.sunPosition = sunPosition
        self.destinationPosition = destinationPosition
        self.estimatedDuration = estimatedDuration
        self.transfer = transfer
        self.simulationTime = simulationTime
        self.routeProgress = routeProgress
        self.stateProvider = stateProvider
    }
}

/// Route geometry construction boundary.
///
/// `NavigationRouteCoordinator` depends on this protocol so route-building policy can vary independently
/// from playback and state publication. The default implementation uses two-body transfer geometry, while
/// tests can inject simpler deterministic builders.
protocol RouteBuilding {
    func makeRoute(input: RouteBuildInput) -> NavigationRoute?
}
