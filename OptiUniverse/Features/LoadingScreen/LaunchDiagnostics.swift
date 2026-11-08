import os

/// Local Instruments intervals separate actual preparation from the deliberate launch animation.
nonisolated enum LaunchDiagnostics {
    static let signposter = OSSignposter(subsystem: "my.OptiUniverse", category: "Launch")
}
