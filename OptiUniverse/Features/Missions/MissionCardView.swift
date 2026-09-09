import SwiftUI

struct MissionCardView: View {
    let mission: Mission

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.line")
                .font(Typography.destinationTitle)
                .foregroundStyle(OptiColor.controlSelectedText)
                .frame(width: 36, height: 36)
                .background(OptiColor.controlSelected, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(Typography.destinationTitle)
                    .foregroundStyle(OptiColor.textPrimary)

                Text(mission.description)
                    .font(Typography.navigationSubtitle)
                    .foregroundStyle(OptiColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(Typography.navigationControl)
                .foregroundStyle(OptiColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .background(OptiColor.screenBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .strokeBorder(OptiColor.controlInactiveStroke, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    MissionCardView(mission: .artemisII)
        .padding()
        .background(OptiColor.screenBackground)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MissionCardView(mission: .artemisII)
        .padding()
        .background(OptiColor.screenBackground)
        .preferredColorScheme(.dark)
}
