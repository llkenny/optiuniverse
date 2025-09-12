import Foundation

/// Thin wrapper accessing corona ray-march steps via `QualityManager`.
enum CoronaQuality {
    /// Number of ray-march steps for the active quality preset.
    static var stepCount: UInt {
        QualityManager.shared.coronaSteps
    }
}

