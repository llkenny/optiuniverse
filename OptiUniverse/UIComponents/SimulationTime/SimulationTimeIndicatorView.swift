import SwiftUI
import UniverseModule

struct SimulationTimeIndicatorView: View {
    let snapshot: SimulationSnapshot
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter
    }()

    private var modeLabel: String {
        switch snapshot.mode {
        case .live: "Live · 1×"
        case .transferPreview: "Transfer preview"
        case .missionReplay: "Mission replay"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(modeLabel)
            Text(Self.formatter.string(from: snapshot.dateUTC))
                .monospacedDigit()
            if let error = snapshot.error {
                Text(error.localizedDescription)
                    .foregroundStyle(.orange)
            }
        }
        .font(Typography.navigationMeta)
        .foregroundStyle(OptiColor.overlayTextSecondary)
        .padding(10)
        .background(OptiColor.overlaySurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }
}
