//
//  RootContainerView+Orbit.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI
import UniverseModule
import BaseModule

extension RootContainerView {

    @ViewBuilder
    func makeOrbitBackButton() -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            let preview = universeResources.transferPreviewSnapshot
            switch preview.status {
            case .preparing:
                ProgressView("Calculating transfer…")
            case .ready:
                if let duration = preview.physicalFlightDuration {
                    Text("Two-body transfer · \(Int((duration / 86_400).rounded())) days · 30 s playback")
                        .font(Typography.navigationMeta)
                }
            case .failed(let failure):
                Text(failure.rawValue).font(Typography.navigationMeta)
                Button("Retry") {
                    if let destination = preview.destinationName {
                        universeResources.transferOrbit.showTransferOrbit(to: destination)
                    }
                }
            case .inactive:
                EmptyView()
            }
            Button {
                universeResources.transferOrbit.clearTransferOrbit()
                objectsViewState = .raw
            } label: {
                Image(systemName: "xmark")
                    .font(Typography.button)
            }
        }
        .foregroundStyle(OptiColor.overlayTextPrimary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .buttonStyle(NeonButtonStyle())
    }
}
