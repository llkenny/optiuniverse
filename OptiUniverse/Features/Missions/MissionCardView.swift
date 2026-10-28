import SwiftUI

struct MissionCardView: View {
    let card: MissionCardModel
    var width: CGFloat = 283

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .title) private var titleSize = 30
    @ScaledMetric(relativeTo: .body) private var bodySize = 14
    @ScaledMetric(relativeTo: .caption) private var dateSize = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 72)

            Text(card.formattedLaunchDate(locale: locale))
                .font(.system(size: dateSize, weight: .semibold))
                .foregroundStyle(OptiColor.onImageSecondary)

            Text(card.mission.title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(OptiColor.onImagePrimary)

            Text(card.mission.goals)
                .font(.system(size: bodySize, weight: .semibold))
                .foregroundStyle(OptiColor.onImagePrimary)

            Text(card.mission.description)
                .font(.system(size: bodySize))
                .foregroundStyle(OptiColor.onImageSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: width, alignment: .leading)
        .frame(minHeight: 360, maxHeight: .infinity, alignment: .bottomLeading)
        .background {
            GeometryReader { geometry in
                Image(card.imageResource)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay {
                        LinearGradient(colors: card.accentColors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.3)
                    }
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.95)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    MissionCardView(card: MissionCardModel(mission: .artemisII))
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .background(OptiColor.screenBackground)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MissionCardView(card: MissionCardModel(mission: .starshipFlight14))
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .background(OptiColor.screenBackground)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    ScrollView {
        MissionCardView(card: MissionCardModel(mission: .crew13))
            .fixedSize(horizontal: false, vertical: true)
            .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .background(OptiColor.screenBackground)
}
