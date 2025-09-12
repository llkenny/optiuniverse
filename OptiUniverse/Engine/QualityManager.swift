import Foundation

/// Represents predefined engine quality presets.
enum QualityPreset: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case cinematic
}

/// Available rendering approaches for the solar corona.
enum CoronaMode: String, Codable {
    case off
    case simple
    case detailed
}

/// Bundle of parameters that scale with a quality preset.
struct QualityConfiguration: Codable {
    /// Number of ray-march steps for volumetric corona rendering.
    let coronaSteps: UInt
    /// Number of particles to emit for effects such as dust or debris.
    let particleCount: Int
    /// Corona rendering technique to use.
    let coronaMode: CoronaMode
}

/// Central manager responsible for runtime quality scaling.
final class QualityManager {
    /// Shared singleton instance.
    static let shared = QualityManager()

    /// Mapping from preset to configuration values.
    private let configs: [QualityPreset: QualityConfiguration]

    /// Currently active preset.
    private(set) var currentPreset: QualityPreset

    private init(bundle: Bundle = .main) {
        if
            let url = bundle.url(forResource: "QualityPresets", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([QualityPreset: QualityConfiguration].self, from: data)
        {
            configs = decoded
        } else {
            configs = [
                .low: .init(coronaSteps: 8, particleCount: 500, coronaMode: .off),
                .medium: .init(coronaSteps: 16, particleCount: 1_000, coronaMode: .simple),
                .high: .init(coronaSteps: 24, particleCount: 2_000, coronaMode: .detailed),
                .cinematic: .init(coronaSteps: 32, particleCount: 4_000, coronaMode: .detailed)
            ]
        }
        currentPreset = .high
    }

    /// Switches to a new quality preset without rebuilding render pipelines.
    func apply(preset: QualityPreset) {
        guard currentPreset != preset else { return }
        currentPreset = preset
        NotificationCenter.default.post(name: .qualityPresetChanged, object: self)
    }

    /// Current number of corona ray-march steps.
    var coronaSteps: UInt { configs[currentPreset]?.coronaSteps ?? 0 }
    /// Current particle emission count.
    var particleCount: Int { configs[currentPreset]?.particleCount ?? 0 }
    /// Currently selected corona rendering mode.
    var coronaMode: CoronaMode { configs[currentPreset]?.coronaMode ?? .off }
}

extension Notification.Name {
    /// Fired whenever the quality preset changes at runtime.
    static let qualityPresetChanged = Notification.Name("QualityPresetChanged")
}

