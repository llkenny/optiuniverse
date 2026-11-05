#if DEBUG
import BaseModule
import Foundation
import Observation
import UniverseModule

/// Each preview owns its real resources, independent of Home and the app's review coordinator.
@Observable
final class ObjectsPreviewModel {
    enum Presentation {
        case scene, details, route
    }

    enum LoadingState: Equatable {
        case loading, loaded, failed(String)
    }

    let environment = AppEnvironment()
    let resources = UniverseModuleFactory.makeResources()
    let initialPresentation: Presentation
    private(set) var loadingState: LoadingState = .loading
    private(set) var destination: DestinationObject?
    private var didInitializePresentation = false
    var objectsViewState: ObjectsViewState = .raw

    init(presentation: Presentation) {
        initialPresentation = presentation
    }

    func prepare() async {
        loadingState = .loading
        do {
            environment.destinationsProvider.fetch()
            guard let mars = environment.destinationsProvider.destinations.first(where: {
                $0.object == "Mars" && $0.title == "Mars"
            }) else {
                loadingState = .failed("The bundled Mars destination is missing.")
                return
            }
            destination = mars
            environment.selectedDestinationID = mars.id
            environment.selectedPlanet = mars.object
            environment.currentScreen = .objects
            try await resources.prepare()
            try Task.checkCancellation()
            loadingState = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    /// Called after the mounted UniverseView has synchronized its initial selection.
    func sceneDidAppear() {
        guard loadingState == .loaded, !didInitializePresentation else { return }
        didInitializePresentation = true
        switch initialPresentation {
        case .scene: break
        case .details: showDetails()
        case .route: showRoute()
        }
    }

    func showDetails() {
        guard let destination else { return }
        objectsViewState = .info(ObjectInfoViewEntity(destination: destination) { [weak self] in
            self?.showRoute()
        })
    }

    func showRoute() {
        guard let destination else { return }
        resources.setObjectInfoOverlayFraming(isPresented: false, bottomInset: 0, viewportHeight: 0)
        resources.transferOrbit.showTransferOrbit(to: destination.object)
        objectsViewState = .orbit
    }

    func closeRoute() {
        resources.transferOrbit.clearTransferOrbit()
        objectsViewState = .raw
    }

    func startNavigation(destinationID: UUID) {
        guard let destination, destination.id == destinationID else { return }
        resources.navigation.startNavigation(to: destination.object)
        objectsViewState = .navigation
    }

    func cancelNavigation() {
        resources.navigation.cancelNavigation()
        objectsViewState = .raw
    }

    func doneNavigation() {
        resources.navigation.doneNavigation()
        objectsViewState = .raw
    }
}
#endif
