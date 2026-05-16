//
//  NeonButtonStyle.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI

struct NeonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(OptiColor.buttonSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .stroke(OptiColor.buttonBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    Button {
        print("Action triggered")
    } label: {
        NeonButtonView(title: "Navigate to")
    }
    .buttonStyle(NeonButtonStyle())
    .padding()
    .background(OptiColor.screenBackground)
}
