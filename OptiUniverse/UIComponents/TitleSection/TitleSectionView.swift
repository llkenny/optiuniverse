//
//  TitleSectionView.swift
//  OptiUniverse
//
//  Created by max on 08.04.2026.
//

import SwiftUI

struct TitleSectionView: View {
    var body: some View {
        HStack {
            Text("Where do you wanna go?")
                .font(Typography.screenTitle)
                .foregroundStyle(OptiColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 60)
        }
    }
}

#Preview {
    VStack {
        TitleSectionView()
        Spacer()
    }
    .padding(.horizontal)
    .background(OptiColor.screenBackground)
}
