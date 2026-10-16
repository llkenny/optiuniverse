import Foundation
import simd

extension RoutePathBuilder {
    static func cislunarLoopOverviewCenter(originPosition: SIMD3<Float>,
                                           waypointPosition: SIMD3<Float>,
                                           destinationPosition: SIMD3<Float>) -> SIMD3<Float> {
        (originPosition + waypointPosition + destinationPosition) / 3
    }

    static func makeCislunarMinorAxis(majorVector: SIMD3<Float>,
                                      length: Float) -> SIMD3<Float> {
        let epsilon: Float = 0.000_001
        let sceneUp = SIMD3<Float>(0, 1, 0)
        guard simd_length_squared(majorVector) > epsilon else {
            return sceneUp * length
        }

        let horizontalMajor = SIMD3<Float>(majorVector.x, 0, majorVector.z)
        if simd_length_squared(horizontalMajor) > epsilon {
            let perpendicular = normalize(SIMD3<Float>(-horizontalMajor.z, 0, horizontalMajor.x))
            return perpendicular * length
        }

        return sceneUp * length
    }

    private static func quadraticBezier(start: SIMD3<Float>,
                                        control: SIMD3<Float>,
                                        end: SIMD3<Float>,
                                        progress: Float) -> SIMD3<Float> {
        let clampedProgress = simd_clamp(progress, 0, 1)
        let inverseProgress = 1 - clampedProgress
        let startWeight = inverseProgress * inverseProgress
        let controlWeight = 2 * inverseProgress * clampedProgress
        let endWeight = clampedProgress * clampedProgress
        return startWeight * start + controlWeight * control + endWeight * end
    }

    private static func cubicBezier(start: SIMD3<Float>,
                                    controlA: SIMD3<Float>,
                                    controlB: SIMD3<Float>,
                                    end: SIMD3<Float>,
                                    progress: Float) -> SIMD3<Float> {
        let clampedProgress = simd_clamp(progress, 0, 1)
        let inverseProgress = 1 - clampedProgress
        return inverseProgress * inverseProgress * inverseProgress * start
            + 3 * inverseProgress * inverseProgress * clampedProgress * controlA
            + 3 * inverseProgress * clampedProgress * clampedProgress * controlB
            + clampedProgress * clampedProgress * clampedProgress * end
    }

    static func quadraticBezierPoints(start: SIMD3<Float>,
                                      control: SIMD3<Float>,
                                      end: SIMD3<Float>,
                                      count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            quadraticBezier(start: start,
                            control: control,
                            end: end,
                            progress: progress)
        }
    }

    static func cubicBezierPoints(start: SIMD3<Float>,
                                  controlA: SIMD3<Float>,
                                  controlB: SIMD3<Float>,
                                  end: SIMD3<Float>,
                                  count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            cubicBezier(start: start,
                        controlA: controlA,
                        controlB: controlB,
                        end: end,
                        progress: progress)
        }
    }

    static func ellipticalArcPoints(center: SIMD3<Float>,
                                    axisA: SIMD3<Float>,
                                    axisB: SIMD3<Float>,
                                    angles: (start: Float, end: Float),
                                    count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            let angle = angles.start + (angles.end - angles.start) * progress
            return center + axisA * cos(angle) + axisB * sin(angle)
        }
    }

    private static func sampledPoints(count: Int,
                                      point: (Float) -> SIMD3<Float>) -> [SIMD3<Float>] {
        let resolvedCount = max(count, 2)
        return (0..<resolvedCount).map { index in
            point(Float(index) / Float(resolvedCount - 1))
        }
    }

    static func predictionSimulationTime(targetProgress: Float,
                                         input: RouteBuildInput) -> Double {
        let remainingProgress = max(simd_clamp(targetProgress, 0, 1)
                                    - simd_clamp(input.routeProgress, 0, 1), 0)
        return input.simulationTime + input.estimatedDuration * Double(remainingProgress)
    }

    static func predictedWorldPosition(ofPlanetNamed planetName: String,
                                       planets: [Planet],
                                       stateProvider: (any CelestialStateProviding)?,
                                       simulationTime: Double) -> SIMD3<Float>? {
        if let stateProvider, let body = CelestialBodyID(rawValue: planetName) {
            return (try? stateProvider.state(for: body, at: simulationTime)).map { SIMD3<Float>($0.scenePosition) }
        }
        var worldPositionsByName: [String: SIMD3<Float>] = [:]
        for planet in planets {
            let parentWorldPosition = planet.parentName.flatMap {
                worldPositionsByName[$0]
            }
            let orbitTransformMatrix = planet.orbitTransformMatrix(
                at: simulationTime,
                parentWorldPosition: parentWorldPosition
            )
            let worldPosition4 = orbitTransformMatrix * SIMD4<Float>(0, 0, 0, 1)
            let worldPosition = SIMD3<Float>(worldPosition4.x,
                                             worldPosition4.y,
                                             worldPosition4.z)
            worldPositionsByName[planet.name] = worldPosition
        }

        return worldPositionsByName[planetName]
    }

    static func normalizeOrFallback(_ vector: SIMD3<Float>,
                                    fallback: SIMD3<Float>) -> SIMD3<Float> {
        let epsilon: Float = 0.000_001
        guard simd_length_squared(vector) > epsilon else {
            return fallback
        }

        return normalize(vector)
    }
}
