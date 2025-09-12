import SwiftUI

/// Simple developer panel enabling runtime tweaking of rendering parameters.
struct DebugPanelView: View {
    @ObservedObject private var quality = QualityManager.shared

    var body: some View {
        Form {
            Section(header: Text("Preset")) {
                Picker("Preset", selection: Binding(
                    get: { quality.currentPreset },
                    set: { quality.apply(preset: $0) }
                )) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue.capitalized).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Corona")) {
                Slider(value: Binding(
                    get: { Double(quality.coronaSteps) },
                    set: { quality.coronaSteps = UInt($0) }
                ), in: 0...64, step: 1) {
                    Text("Steps")
                }
                Text("Steps: \(quality.coronaSteps)")

                Picker("Mode", selection: $quality.coronaMode) {
                    Text("Off").tag(CoronaMode.off)
                    Text("Simple").tag(CoronaMode.simple)
                    Text("Detailed").tag(CoronaMode.detailed)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Particles")) {
                Slider(value: Binding(
                    get: { Double(quality.particleCount) },
                    set: { quality.particleCount = Int($0) }
                ), in: 0...5000, step: 100) {
                    Text("Count")
                }
                Text("Count: \(quality.particleCount)")
            }

            Section(header: Text("Exposure")) {
                Slider(value: $quality.exposure, in: 0.1...5.0) {
                    Text("Exposure")
                }
                Text(String(format: "%.2f", quality.exposure))
            }
        }
    }
}

#Preview {
    DebugPanelView()
}
