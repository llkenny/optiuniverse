//
//  DestinationCardView.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

struct DestinationCardView: View {
    let model: DestinationCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer()

            Text(model.title)
                .font(Typography.destinationTitle)
                .foregroundStyle(OptiColor.onImagePrimary)
                .lineLimit(1)

            Text(model.subtitle)
                .font(Typography.destinationSubtitle)
                .foregroundStyle(OptiColor.onImageSecondary)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .aspectRatio(1, contentMode: .fit)
        .background {
            Image(model.imageResource)
                .resizable()
                .scaledToFill()

            LinearGradient(colors: [.clear, OptiColor.imageScrim],
                           startPoint: .center,
                           endPoint: .bottom)
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }
}

#Preview {
    DestinationCardView(model: .init(id: .init(),
                                     title: "Mars mountains",
                                     subtitle: "Dusty Red Planet",
                                     imageResource: .dstMercury,
                                     tag: "nil"))
    .frame(width: 174)
    .clipped()
}
