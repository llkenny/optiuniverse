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
    func makeInfoButton(selectedDestinationID: UUID) -> some View {
        Button {
            makeObjectInfo(selectedDestinationID: selectedDestinationID)
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
                        hideObjectInfoOverlay(viewportHeight: containerProxy.size.height)
                    }

                ObjectInfoView(entity: entity)
                    .offset(y: objectInfoDragOffset)
                    .gesture(makeObjectInfoDismissGesture(viewportHeight: containerProxy.size.height))
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        setObjectInfoOverlayFraming(
                            overlayHeight: size.height,
                            viewportHeight: containerProxy.size.height
                        )
                    }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.default, value: objectInfoDragOffset)
    }

    private func setObjectInfoOverlayFraming(overlayHeight: CGFloat,
                                             viewportHeight: CGFloat) {
        metalResources.setObjectInfoOverlayFraming(isPresented: true,
                                                   bottomInset: overlayHeight,
                                                   viewportHeight: viewportHeight)
    }

    private func hideObjectInfoOverlay(viewportHeight: CGFloat) {
        metalResources.setObjectInfoOverlayFraming(isPresented: false,
                                                   bottomInset: 0,
                                                   viewportHeight: viewportHeight)
        objectsViewState = .raw
    }

    private func makeObjectInfoDismissGesture(viewportHeight: CGFloat) -> some Gesture {
        DragGesture()
            .updating($objectInfoDragOffset) { value, state, _ in
                state = max(value.translation.height, 0)
            }
            .onEnded { value in
                let translationThreshold: CGFloat = 80
                let predictedTranslationThreshold: CGFloat = 140
                let shouldDismiss = value.translation.height > translationThreshold ||
                    value.predictedEndTranslation.height > predictedTranslationThreshold

                if shouldDismiss {
                    hideObjectInfoOverlay(viewportHeight: viewportHeight)
                }
            }
    }

    private func makeObjectInfo(selectedDestinationID: UUID) {
        guard let destination = appEnvironment.destinationsProvider
            .destinations
            .first(where: {
                $0.id == selectedDestinationID
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
                                          imageName: destination.infoImageName,
                                          title: destination.title,
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
            metalResources.transferOrbit.showTransferOrbit(to: destination.object)
            objectsViewState = .orbit
        })
        objectInfoOverlayPresentationID = UUID()
        objectsViewState = .info(entity)
    }
}
