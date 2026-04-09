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
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .frame(width: 283, height: 291)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                
                Spacer()
                
                Text(card.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(card.subtitle.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview {
    HeroCardView(card: HeroCard(
        id: UUID(),
        imageResource: .neptune1,
        title: "Saturn",
        subtitle: "Ringed giant",
        accentColors: [Color(red: 0.97, green: 0.72, blue: 0.42),
                       Color(red: 0.34, green: 0.16, blue: 0.08)]
    ))
}
