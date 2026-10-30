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

    var body: some View {
        Text(Self.formatter.string(from: snapshot.dateUTC))
            .monospacedDigit()
            .font(Typography.navigationMeta)
            .foregroundStyle(OptiColor.overlayTextSecondary)
            .accessibilityIdentifier("simulationTimeIndicator")
            .allowsHitTesting(false)
    }
}
