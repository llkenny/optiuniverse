import SwiftUI

struct MissionCardView: View {
    let mission: Mission

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OptiColor.overlayTextPrimary)

                Text(mission.title)
                    .font(Typography.navigationTitle)
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .lineLimit(1)
            }

            Text(mission.description)
                .font(Typography.navigationSubtitle)
                .foregroundStyle(OptiColor.overlayTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 184, height: 82, alignment: .leading)
        .background(OptiColor.overlaySurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.detailCard, style: .continuous)
                .stroke(OptiColor.overlayBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard, style: .continuous))
    }
}

#Preview {
    MissionCardView(mission: .artemisII)
        .padding()
        .background(OptiColor.screenBackground)
}
