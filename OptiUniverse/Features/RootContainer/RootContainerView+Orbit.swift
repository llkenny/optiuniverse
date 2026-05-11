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
    func makeOrbitSummary(summary: TransferOrbitSummary) -> some View {
        TransferOrbitFormulaOverlay(summary: summary)
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topTrailing)
    }

    @ViewBuilder
    func makeOrbitBackButton() -> some View {
        Button {
            appEnvironment.currentScreen = .home
        } label: {
            Text("✖️")
                .foregroundStyle(.neonTextPrimary)
                .font(.system(size: 16))
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .bottomTrailing)
        .padding(.trailing)
        .buttonStyle(NeonButtonStyle())
    }
}
