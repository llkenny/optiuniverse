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

    @ScaledMetric(relativeTo: .caption2) private var captionSize = 8
    @ScaledMetric(relativeTo: .caption) private var valueSize = 10

    var body: some View {
        VStack {
            Text(entity.title.uppercased())
                .font(.system(size: captionSize))
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
            Text(entity.value.uppercased())
                .font(.system(size: valueSize))
                .foregroundStyle(OptiColor.objectInfoTextPrimary)
            Text(entity.dimension.uppercased())
                .font(.system(size: captionSize))
                .foregroundStyle(OptiColor.objectInfoTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .multilineTextAlignment(.center)
        .background(OptiColor.objectInfoSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.detailCard))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.detailCard)
                .stroke(OptiColor.objectInfoBorder, lineWidth: 1)
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
