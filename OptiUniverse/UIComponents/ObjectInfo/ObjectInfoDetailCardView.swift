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
                .font(.system(size: 8))
                .foregroundStyle(.neonTextSecondary)
            Text(entity.value.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(.neonTextPrimary)
            Text(entity.dimension.uppercased())
                .font(.system(size: 8))
                .foregroundStyle(.neonTextSecondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.neonSectionFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.neonSectionBorder, lineWidth: 1)
        )
    }
}

#Preview {
    ObjectInfoDetailCardView(entity: .init(title: "dinstance",
                                           value: "0.39",
                                           dimension: "AU"))
    .frame(height: 10)
}
