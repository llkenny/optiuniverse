import Foundation

/// Quality preset controlling corona ray-march step count.
enum CoronaQualityPreset: Int {
    case low
    case medium
    case high

    /// Number of ray-march steps for the preset.
    var stepCount: UInt {
        switch self {
        case .low: return 8
        case .medium: return 16
        case .high: return 24
        }
    }
}

