//
//  CameraTransition.swift
//  UniverseModule
//
//  Created by Codex on 13.05.2026.
//

import simd

struct CameraTransition {
    struct Frame: Equatable {
        let target: SIMD3<Float>
        let distance: Float
        let orientation: simd_quatf?

        init(target: SIMD3<Float>,
             distance: Float,
             orientation: simd_quatf? = nil) {
            self.target = target
            self.distance = distance
            self.orientation = orientation
        }
    }

    enum Destination: Equatable {
        case planet(name: String)
        case fixed(target: SIMD3<Float>, distance: Float, orientation: simd_quatf? = nil)
    }

    let start: Frame
    let destination: Destination
    let duration: Float
    private(set) var elapsed: Float = 0

    var progress: Float {
        guard duration > 0 else { return 1 }
        return min(max(elapsed / duration, 0), 1)
    }

    var isComplete: Bool {
        progress >= 1
    }

    init(start: Frame,
         destination: Destination,
         duration: Float) {
        self.start = start
        self.destination = destination
        self.duration = max(duration, 0.001)
    }

    mutating func advance(delta: Float,
                          resolveDestination: (Destination) -> Frame?) -> Frame? {
        guard let end = resolveDestination(destination) else { return nil }

        elapsed = min(max(elapsed + max(delta, 0), 0), duration)
        return Self.interpolate(from: start,
                                to: end,
                                progress: easedProgress)
    }

    var easedProgress: Float {
        Self.easeInOutCubic(progress)
    }

    static func interpolate(from start: Frame,
                            to end: Frame,
                            progress: Float) -> Frame {
        let clampedProgress = min(max(progress, 0), 1)
        return Frame(
            target: start.target + (end.target - start.target) * clampedProgress,
            distance: start.distance + (end.distance - start.distance) * clampedProgress,
            orientation: interpolatedOrientation(from: start.orientation,
                                                 to: end.orientation,
                                                 progress: clampedProgress)
        )
    }

    private static func interpolatedOrientation(from start: simd_quatf?,
                                                to end: simd_quatf?,
                                                progress: Float) -> simd_quatf? {
        guard let start, let end else { return nil }
        return simd_normalize(simd_slerp(start, end, progress))
    }

    static func easeInOutCubic(_ value: Float) -> Float {
        let clampedValue = min(max(value, 0), 1)
        if clampedValue < 0.5 {
            return 4 * clampedValue * clampedValue * clampedValue
        }

        let inverseProgress = -2 * clampedValue + 2
        return 1 - (inverseProgress * inverseProgress * inverseProgress) / 2
    }
}
