import simd

/// Stable phase parameters survive changes in segment lengths as Earth and Moon move.
struct ArtemisPathSamples {
    var points: [SIMD3<Float>] = []
    var progresses: [Float] = []

    mutating func append(_ segment: [SIMD3<Float>], from start: Float, to end: Float) {
        let distances = RoutePathBuilder.makeCumulativeDistances(points: segment)
        guard let total = distances.last, total > 0 else { return }
        let first = points.isEmpty ? 0 : 1
        for index in segment.indices where index >= first {
            points.append(segment[index])
            progresses.append(start + (end - start) * distances[index] / total)
        }
        // Avoid roundoff at phase joins, particularly the dated lunar encounter.
        progresses[progresses.count - 1] = end
    }
}
