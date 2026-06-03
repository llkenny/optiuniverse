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
        GeometryReader { containerProxy in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        metalResources.setObjectInfoOverlayFraming(isPresented: false,
                                                                    bottomInset: 0,
                                                                    viewportHeight: containerProxy.size.height)
                        objectsViewState = .raw
                    }

                ObjectInfoView(entity: entity)
                    .background {
                        GeometryReader { overlayProxy in
                            Color.clear
                                .onAppear {
                                    setObjectInfoOverlayFraming(overlayHeight: overlayProxy.size.height,
                                                                viewportHeight: containerProxy.size.height)
                                }
                                .onChange(of: overlayProxy.size.height) { _, newHeight in
                                    setObjectInfoOverlayFraming(overlayHeight: newHeight,
                                                                viewportHeight: containerProxy.size.height)
                                }
                                .onChange(of: containerProxy.size.height) { _, newHeight in
                                    setObjectInfoOverlayFraming(overlayHeight: overlayProxy.size.height,
                                                                viewportHeight: newHeight)
                                }
                        }
                    }
            }
            .onDisappear {
                metalResources.setObjectInfoOverlayFraming(isPresented: false,
                                                            bottomInset: 0,
                                                            viewportHeight: containerProxy.size.height)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func setObjectInfoOverlayFraming(overlayHeight: CGFloat,
                                             viewportHeight: CGFloat) {
        metalResources.setObjectInfoOverlayFraming(isPresented: true,
                                                    bottomInset: overlayHeight,
                                                    viewportHeight: viewportHeight)
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
        let orbitInfo = destination.orbitInfo.map {
            ObjectInfoOrbitView.Model(
                description: $0.description,
                properties: [
                    .axis: $0.properties.axis,
                    .eccentricity: $0.properties.eccentricity,
                    .inclination: $0.properties.inclination
                ]
            )
        }

        let entity = ObjectInfoViewEntity(id: destination.id,
                                          title: selectedPlanet,
                                          subtitle: destination.subtitle,
                                          description: destination.description,
                                          details: details,
                                          navigationButtonTitle: "🎯 Route",
                                          isNavigable: destination.isNavigable,
                                          orbitInfo: orbitInfo,
                                          navigationButtonAction: {
            metalResources.setObjectInfoOverlayFraming(isPresented: false,
                                                        bottomInset: 0,
                                                        viewportHeight: 0)
            metalResources.transferOrbit.showTransferOrbit(to: selectedPlanet)
            objectsViewState = .orbit
        })
        objectsViewState = .info(entity)
    }
}
