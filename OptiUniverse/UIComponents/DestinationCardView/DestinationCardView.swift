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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(model.subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white)
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
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

#Preview {
    DestinationCardView(model: .init(id: .init(),
                                     object: "Mars",
                                     title: "Mars mountains",
                                     subtitle: "Dusty Red Planet",
                                     imageResource: .dstMercury,
                                     tag: "nil"))
    .frame(width: 174)
    .clipped()
}
