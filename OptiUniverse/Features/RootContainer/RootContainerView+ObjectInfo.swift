//
//  RootContainerView+ObjectInfo.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI
import BaseModule
import MetalModule

extension RootContainerView {

    @ViewBuilder
    func makeInfoButton(selectedPlanet: String) -> some View {
        Button {
            Task {
                await makeObjectInfo(selectedPlanet: selectedPlanet)
            }
        } label: {
            Text("🔭")
                .foregroundStyle(.neonTextPrimary)
                .font(.system(size: 16))
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .bottomTrailing)
        .padding(.trailing)
        .buttonStyle(NeonButtonStyle())
    }

    @ViewBuilder
    func makeInfoOverlay(entity: ObjectInfoViewEntity) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    objectsViewState = .raw
                }

            ObjectInfoView(entity: entity)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func makeObjectInfo(selectedPlanet: String) async {
        guard let destination = await appEnvironment.destinationsProvider
            .destinations
            .first(where: {
                $0.title == selectedPlanet
            }) else {
            return
        }
        let entity = ObjectInfoViewEntity(id: destination.id,
                                          title: selectedPlanet,
                                          subtitle: destination.subtitle,
                                          description: destination.description,
                                          details: [], // TODO: Provide details
                                          navigationButtonTitle: "Route",
                                          navigationButtonAction: {
            orbitRenderHandler.showTransferOrbit(to: selectedPlanet)
            guard let summary = orbitRenderHandler.transferOrbitSummary else {
                return
            }
            objectsViewState = .orbit(summary)
        })
        objectsViewState = .info(entity)
    }
}
