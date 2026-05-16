//
//  TitleSectionView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct TitleSectionView: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi \(name),")
                .font(Typography.greeting)
                .foregroundStyle(OptiColor.textSecondary)
            HStack {
                Text("Where do you wanna go?")
                    .font(Typography.screenTitle)
                    .foregroundStyle(OptiColor.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack {
        TitleSectionView(name: "Stranger")
        Spacer()
    }
    .padding(.horizontal)
    .background(OptiColor.screenBackground)
}
