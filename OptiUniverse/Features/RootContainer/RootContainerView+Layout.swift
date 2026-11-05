import SwiftUI
import BaseModule
import UniverseModule
#if os(iOS)
import UIKit
#endif

extension RootContainerView {
    var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    func makeContent(usesVerticalToolbar: Bool, onMissionSelected: @escaping (Mission) -> Void) -> some View {
        let allowsExpandedLayout = AdaptiveLayoutPolicy.allowsExpandedLayout(windowSize: windowSize, isPad: isPad)
        return ZStack {
            // This slot stays mounted beneath Home, including while native bars change axis.
            ObjectsView(universeResources: universeResources,
                        objectsViewState: $objectsViewState,
                        isActive: appEnvironment.currentScreen == .objects,
                        selectedDestinationID: appEnvironment.selectedDestinationID,
                        mission: missionFlowState?.mission.flightPlan,
                        allowsExpandedLayout: allowsExpandedLayout,
                        usesVerticalToolbar: usesVerticalToolbar,
                        onStartNavigation: startNavigation,
                        onRetryTransfer: retryTransferPreview,
                        onRetryNavigation: retryNavigation,
                        onDoneNavigation: { universeResources.navigation.doneNavigation() })
            if appEnvironment.currentScreen == .home {
                HomeView(onMissionSelected: onMissionSelected, allowsExpandedLayout: allowsExpandedLayout)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
