//
//  RootContainerView+ObjectInfo.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI
import BaseModule
import UniverseModule

extension RootContainerView {

    func clearObjectInfoFraming() {
        objectInfoPanelFrame = .zero
        universeResources.setObjectInfoOverlayFraming(isPresented: false,
                                                     bottomInset: 0,
                                                     viewportHeight: 0)
    }

    func hideObjectInfoOverlay() {
        clearObjectInfoFraming()
        objectsViewState = .raw
    }

    func makeObjectInfo(selectedDestinationID: UUID) {
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
            universeResources.setObjectInfoOverlayFraming(isPresented: false,
                                                       bottomInset: 0,
                                                       viewportHeight: 0)
            universeResources.transferOrbit.showTransferOrbit(to: destination.object)
            objectsViewState = .orbit
        })
        objectsViewState = .info(entity)
    }
}
