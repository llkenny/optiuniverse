import SwiftUI
import BaseModule
import UniverseModule

extension RootContainerView {
    func makeObjectInfo(selectedDestinationID: UUID) {
        guard let destination = appEnvironment.destinationsProvider.destinations.first(where: {
            $0.id == selectedDestinationID
        }) else { return }

        objectsViewState = .info(ObjectInfoViewEntity(destination: destination) {
            universeResources.setObjectInfoOverlayFraming(isPresented: false, bottomInset: 0, viewportHeight: 0)
            universeResources.transferOrbit.showTransferOrbit(to: destination.object)
            objectsViewState = .orbit
        })
    }
}
