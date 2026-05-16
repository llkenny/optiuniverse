//
//  HeroCardView.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI

struct HeroCardView: View {
    let card: HeroCard

    var body: some View {
        ZStack {
            Image(card.imageResource)
                .resizable()
                .scaledToFill()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: card.accentColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.5)

            LinearGradient(
                colors: [.clear, OptiColor.imageScrim],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .frame(width: 283, height: 291)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {

                Spacer()

                Text(card.title)
                    .font(Typography.pageCardTitle)
                    .foregroundStyle(OptiColor.onImagePrimary)
                    .lineLimit(1)

                Text(card.subtitle.uppercased())
                    .font(Typography.pageCardCaption)
                    .tracking(1.4)
                    .foregroundStyle(OptiColor.onImageSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.heroCard, style: .continuous))
    }
}

#Preview {
    HeroCardView(card: HeroCard(
        id: UUID(),
        imageResource: .neptune1,
        title: "Saturn",
        subtitle: "Ringed giant",
        accentColors: [.orange, .brown]
    ))
    .padding()
    .background(OptiColor.screenBackground)
}
