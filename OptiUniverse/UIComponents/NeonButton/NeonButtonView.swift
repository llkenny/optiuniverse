//
//  NeonButtonView.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI

struct NeonButtonView: View {
    let title: String

    var body: some View {
        Text(title)
            .foregroundStyle(OptiColor.overlayTextPrimary)
            .font(Typography.button)
            .padding(.bottom, 2)
    }
}

#Preview {
    NeonButtonView(title: "🎯 Navigate to")
        .padding()
        .background(OptiColor.buttonSurface)
}
