import Foundation
import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@Test func lambertMatchesESACircularReference() throws {
    // ESA pykep Lambert documentation: r0=(1,0,0), r1=(0,1,0), dt=pi/2, mu=1.
    let solution = try LambertSolver.solve(from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0), duration: .pi / 2, mu: 1)
    #expect(simd_distance(solution.departure, SIMD3(0, 1, 0)) < 1e-11)
    #expect(simd_distance(solution.arrival, SIMD3(-1, 0, 0)) < 1e-11)
}

@Test func lambertMatchesIndependentValladoReference() throws {
    let start = SIMD3<Double>(5_000, 10_000, 2_100)
    let end = SIMD3<Double>(-14_600, 2_500, 7_000)
    let solution = try LambertSolver.solve(from: start, to: end, duration: 3_600, mu: 398_600.4418)
    #expect(simd_distance(solution.departure, SIMD3(-5.99249502, 1.92536671, 3.24563805)) < 1e-7)
    #expect(simd_distance(solution.arrival, SIMD3(-3.31245850, -4.19661901, -0.38528906)) < 1e-7)
}

@Test func transferInterceptsMovingPlanetsAndConservesInvariants() throws {
    for name in ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"] {
        let solution = try TransferSolution.make(destinationName: name, planets: testPlanets, departureEpoch: 0)
        let target = try #require(testPlanets.first { $0.name == name }?.orbit)
        let end = try solution.trajectory.state(after: solution.flightDuration)
        #expect(simd_distance(end.position, target.state(at: solution.arrivalEpoch).position) < 10)
        #expect(simd_distance(end.velocity, solution.arrivalVelocity) < 1e-6)
        let start = try solution.trajectory.state(after: 0)
        let energy = simd_length_squared(start.velocity) / 2 - TwoBodyTrajectory.solarMu / simd_length(start.position)
        let momentum = simd_cross(start.position, start.velocity)
        for fraction in [0.1, 0.5, 0.9] {
            let state = try solution.trajectory.state(after: solution.flightDuration * fraction)
            let currentEnergy = simd_length_squared(state.velocity) / 2 - TwoBodyTrajectory.solarMu / simd_length(state.position)
            #expect(abs(currentEnergy - energy) < 1e-7)
            #expect(simd_length(simd_cross(state.position, state.velocity) - momentum) / simd_length(momentum) < 1e-10)
        }
    }
}

@Test func lambertRejectsDegenerateGeometry() {
    #expect(throws: TransferFailure.invalidGeometry) {
        try LambertSolver.solve(from: SIMD3(1, 0, 0), to: SIMD3(-1, 0, 0), duration: 1, mu: 1)
    }
    #expect(throws: TransferFailure.invalidGeometry) {
        try TransferSolution.make(destinationName: "Moon", planets: testPlanets, departureEpoch: 0)
    }
}

@MainActor
@Test func journeyClockAndSpacecraftArriveTogetherInThirtySeconds() throws {
    var published = NavigationRouteSnapshot.idle
    let coordinator = NavigationRouteCoordinator(snapshotPublisher: { published = $0 })
    #expect(coordinator.start(destinationName: "Mars", planets: testPlanets, snapshot: orbitalTestSnapshot()))
    let route = try #require(coordinator.route)
    let transfer = try #require(route.transfer)
    var clock = UniverseSimulationClock()
    for _ in 0..<60 {
        _ = clock.advance(by: 0.5, transfer: transfer)
        coordinator.update(simulationTime: clock.currentTime, delta: 0.5)
    }
    #expect(abs(clock.currentTime - transfer.arrivalEpoch) < 1e-7)
    #expect(published.state == .completed)
    #expect(published.elapsedTime == 30)
    let snapshot = orbitalTestSnapshot(time: clock.currentTime)
    let target = try #require(snapshot.worldPosition(ofPlanetNamed: "Mars"))
    #expect(simd_distance(try #require(coordinator.currentRoutePoint), target) < 1e-4)
    #expect(clock.presentationTime == 30)
    _ = clock.advance(by: 1)
    #expect(abs(clock.currentTime - transfer.arrivalEpoch - 86_400) < 1e-7)
}

@MainActor
@Test func navigationLocksTrajectoryAndIgnoresOlderSnapshots() throws {
    let coordinator = NavigationRouteCoordinator(snapshotPublisher: { _ in })
    #expect(coordinator.start(destinationName: "Mars", planets: testPlanets, snapshot: orbitalTestSnapshot()))
    let route = try #require(coordinator.route)
    let transfer = try #require(route.transfer)
    coordinator.update(simulationTime: transfer.departureEpoch + transfer.flightDuration / 2)
    #expect(abs(coordinator.renderProgress - 0.5) < 1e-6)
    coordinator.update(simulationTime: transfer.departureEpoch)
    coordinator.refreshRoute(planets: testPlanets, snapshot: orbitalTestSnapshot(time: transfer.arrivalEpoch))
    #expect(abs(coordinator.renderProgress - 0.5) < 1e-6)
    #expect(coordinator.route == route)
    coordinator.cancel()
    #expect(coordinator.route == nil)
}

@Test func independentRungeKuttaIntegrationReachesLambertDestination() throws {
    let solution = try TransferSolution.make(destinationName: "Mars", planets: testPlanets, departureEpoch: 0)
    var position = solution.trajectory.initialPosition
    var velocity = solution.departureVelocity
    let step = solution.flightDuration / 8_192
    func acceleration(_ position: SIMD3<Double>) -> SIMD3<Double> {
        -TwoBodyTrajectory.solarMu * position / pow(simd_length(position), 3)
    }
    for _ in 0..<8_192 {
        let firstPosition = velocity
        let firstVelocity = acceleration(position)
        let secondPosition = velocity + firstVelocity * (step / 2)
        let secondVelocity = acceleration(position + firstPosition * (step / 2))
        let thirdPosition = velocity + secondVelocity * (step / 2)
        let thirdVelocity = acceleration(position + secondPosition * (step / 2))
        let fourthPosition = velocity + thirdVelocity * step
        let fourthVelocity = acceleration(position + thirdPosition * step)
        let positionMiddle = (secondPosition + thirdPosition) * 2.0
        let velocityMiddle = (secondVelocity + thirdVelocity) * 2.0
        let positionSlope = firstPosition + positionMiddle + fourthPosition
        let velocitySlope = firstVelocity + velocityMiddle + fourthVelocity
        position += positionSlope * (step / 6)
        velocity += velocitySlope * (step / 6)
    }
    let mars = try #require(testPlanets.first { $0.name == "Mars" }?.orbit)
    #expect(simd_distance(position, mars.state(at: solution.arrivalEpoch).position) < 1)
    #expect(simd_distance(velocity, solution.arrivalVelocity) < 1e-6)
}

@Test func hyperbolicAndNearParabolicLambertArcsPropagateCorrectly() throws {
    for duration in [0.1, 0.95, 0.9767170884383225, 1.0, 8.0] {
        let end = SIMD3<Double>(0, 1, 0)
        let velocities = try LambertSolver.solve(from: SIMD3(1, 0, 0), to: end, duration: duration, mu: 1)
        let trajectory = TwoBodyTrajectory(initialPosition: SIMD3(1, 0, 0),
                                            initialVelocity: velocities.departure, mu: 1)
        let state = try trajectory.state(after: duration)
        #expect(simd_distance(state.position, end) < 1e-9)
        #expect(simd_distance(state.velocity, velocities.arrival) < 1e-9)
    }
}

@Test func minimumRadiusIncludesPeriapsisBetweenSamples() {
    // Ellipse with a=1, e=0.8, from the negative-y minor-axis point to positive y, crossing periapsis.
    let trajectory = TwoBodyTrajectory(initialPosition: SIMD3(0, -0.36, 0),
                                        initialVelocity: SIMD3(1 / 0.6, 0.8 / 0.6, 0), mu: 1)
    #expect(abs(trajectory.minimumRadius(endingAt: SIMD3(0, 0.36, 0)) - 0.2) < 1e-10)
}

@Test func playbackAdvancesOnlyWithActiveFrameTime() {
    let playback = RoutePlaybackController()
    playback.start(duration: 16)
    playback.advance(by: 4)
    playback.update()
    #expect(playback.progress == 0.25)
    playback.update()
    playback.advance(by: .nan)
    playback.advance(by: -5)
    #expect(playback.progress == 0.25)
    playback.advance(by: 12)
    playback.update()
    #expect(playback.isCompleted)
}

@MainActor
@Test func backgroundResumeDiscardsSuspendedFrameDelta() throws {
    let resources = UniverseModuleResources()
    resources.setViewportSize(CGSize(width: 390, height: 844))
    let coordinator = resources.sceneCoordinator
    coordinator.update(deltaTime: 1)
    let initial = try #require(coordinator.latestFrameState)
    coordinator.setPresentationActive(false)
    coordinator.update(deltaTime: 100)
    coordinator.setPresentationActive(true)
    coordinator.update(deltaTime: 100)
    #expect(coordinator.latestFrameState?.simulationTime == initial.simulationTime)
    coordinator.update(deltaTime: 1)
    #expect(coordinator.latestFrameState?.simulationTime == initial.simulationTime + 86_400)
}

@MainActor
@Test func cancellingJourneyRestoresNormalOrbitalRateWithoutRewinding() throws {
    let resources = UniverseModuleResources()
    resources.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startNavigation(to: "Mars")
    let transfer = try #require(resources.navigationController.activeTransfer)
    resources.sceneCoordinator.update(deltaTime: 15)
    let halfway = try #require(resources.sceneCoordinator.latestFrameState)
    #expect(abs(halfway.simulationTime - transfer.flightDuration / 2) < 1e-6)
    #expect(abs(resources.navigationSnapshot.progress - 0.5) < 1e-6)
    #expect(halfway.presentationTime == 15)
    resources.navigation.cancelNavigation()
    resources.sceneCoordinator.update(deltaTime: 1)
    let cancelled = try #require(resources.sceneCoordinator.latestFrameState)
    #expect(abs(cancelled.simulationTime - halfway.simulationTime - 86_400) < 1e-6)
    #expect(resources.navigationController.activeTransfer == nil)
}
