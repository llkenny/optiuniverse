//
//  ObjectInfoDetailCardView.swift
//  OptiUniverse
//
//  Created by max on 13.05.2026.
//

import SwiftUI

struct ObjectInfoDetailCardEntity {
    let title: String
    let value: String
    let dimension: String
}

struct ObjectInfoDetailCardView: View {
    let entity: ObjectInfoDetailCardEntity

    var body: some View {
        VStack {
            Text(entity.title.uppercased())
                .font(Typography.overlayCaption)
                .foregroundStyle(OptiColor.overlayTextSecondary)
            Text(entity.value.uppercased())
                .font(Typography.overlayValue)
                .foregroundStyle(OptiColor.overlayTextPrimary)
            Text(entity.dimension.uppercased())
                .font(Typography.overlayCaption)
                .foregroundStyle(OptiColor.overlayTextSecondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(OptiColor.overlaySurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.detailCard)
                .stroke(OptiColor.overlayBorder, lineWidth: 1)
        )
    }
}

#Preview {
    ObjectInfoDetailCardView(entity: .init(title: "distance",
                                           value: "0.39",
                                           dimension: "AU"))
    .frame(height: 44)
    .padding()
    .background(.black)
}
