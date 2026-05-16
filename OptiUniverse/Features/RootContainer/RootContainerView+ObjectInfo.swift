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
        let details = destination.details.map {
            ObjectInfoDetailCardEntity(title: $0.title,
                                       value: $0.value,
                                       dimension: $0.dimension)
        }

        let entity = ObjectInfoViewEntity(id: destination.id,
                                          title: selectedPlanet,
                                          subtitle: destination.subtitle,
                                          description: destination.description,
                                          details: details,
                                          navigationButtonTitle: "🎯 Route",
                                          isNavigable: destination.isNavigable,
                                          navigationButtonAction: {
            orbitRenderHandler.showTransferOrbit(to: selectedPlanet)
            objectsViewState = .orbit
        })
        objectsViewState = .info(entity)
    }
}
