//
//  TransferOrbitFormulaOverlay.swift
//  OptiUniverse
//
//  Created by max on 06.05.2026.
//

import SwiftUI
import MetalModule

struct TransferOrbitFormulaOverlay: View {
    let summary: TransferOrbitSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hohmann transfer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text("a = (r1 + r2) / 2")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("r1 Earth: \(formatted(summary.earthOrbitRadiusAU)) AU")
                Text("r2 \(summary.destinationName): \(formatted(summary.destinationOrbitRadiusAU)) AU")
                Text("a: \(formatted(summary.semiMajorAxisAU)) AU")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ value: Float) -> String {
        String(format: "%.3f", Double(value))
    }
}
