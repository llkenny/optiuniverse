//
//  RootContainerView+Orbit.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI
import MetalModule
import BaseModule

extension RootContainerView {

    @ViewBuilder
    func makeOrbitBackButton() -> some View {
        Button {
            appEnvironment.currentScreen = .home
        } label: {
            Image(systemName: "xmark")
                .foregroundStyle(OptiColor.overlayTextPrimary)
                .font(Typography.button)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .bottomTrailing)
        .padding(.trailing)
        .buttonStyle(NeonButtonStyle())
    }
}
