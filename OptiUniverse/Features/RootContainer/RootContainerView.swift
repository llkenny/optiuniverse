//
//  RootContainerView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import UniverseModule
import BaseModule
import Foundation
import StoreKit

struct RootContainerView: View {

    private enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Environment(AppEnvironment.self) var appEnvironment
    #if os(iOS)
    @Environment(ReviewRequestCoordinator.self) private var reviewCoordinator
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    #endif
    @State private var isShowingLegalCredits = false
    @State private var loadingState: LoadingState = .loading
    @State private var loadingAttempt = 0
    @State var missionFlowState: MissionFlowState?
    @State var pendingMissionAdvance: MissionFlowAdvance?
    @State var objectsViewState: ObjectsViewState = .raw
    @State var universeViewportFrame: CGRect = .zero
    @State var objectInfoPanelFrame: CGRect = .zero
    let universeResources: UniverseModuleResources

    init(universeResources: UniverseModuleResources) {
        self.universeResources = universeResources
    }

    var body: some View {
        // Keep the navigation container and scene mounted as native bars change their axis.
        NavigationStack {
            content
                .navigationTitle(navigationBarTitle)
                #if os(iOS)
                .navigationSubtitle(navigationBarSubtitle)
                #endif
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { navigationControls }
                .toolbarBackground(isUniverseVisible ? .hidden : .automatic, for: .navigationBar, .bottomBar)
                .toolbarColorScheme(isUniverseVisible ? .dark : nil, for: .navigationBar, .bottomBar)
                .toolbarVisibility(loadingState == .loaded ? .visible : .hidden, for: .navigationBar)
                .toolbarVisibility(showsObjectDetailsButton ? .visible : .hidden, for: .bottomBar)
        }
        .preferredColorScheme(isUniverseVisible ? .dark : nil)
        .sheet(isPresented: $isShowingLegalCredits) {
            LegalCreditsView()
        }
    }

    private var content: some View {
        ZStack {
            OptiColor.screenBackground
                .ignoresSafeArea()

            switch loadingState {
            case .loaded:
                makeContent(onMissionSelected: startMission)
            case .loading:
                LoadingScreenView()
            case .failed(let message):
                UniverseLoadingFailureView(message: message) {
                    loadingState = .loading
                    loadingAttempt += 1
                }
            }
        }
        .animation(.default, value: loadingState)
        .animation(.default, value: appEnvironment.currentScreen)
        .animation(.default, value: universeResources.navigation.navigationSnapshot)
        .onChange(of: appEnvironment.currentScreen) { _, newScreen in
            guard newScreen == .home else { return }

            cancelObjectPresentationModes()
        }
        .onChange(of: appEnvironment.selectedDestinationID) { _, _ in
            // Mission launch clears the destination and sets navigation in the same update.
            guard missionFlowState == nil else { return }
            clearObjectInfoFraming()
            objectsViewState = .raw
        }
        .onChange(of: universeResources.navigation.navigationSnapshot) { _, snapshot in
            #if os(iOS)
            reviewCoordinator.navigationChanged(routeID: snapshot.routeID, state: snapshot.state)
            #endif
            handleNavigationSnapshotChange(snapshot)
        }
        #if os(iOS)
        .onChange(of: reviewPresentationContext, initial: true) { _, context in
            let action = requestReview
            reviewCoordinator.updatePresentation(context, requestReview: { action() })
        }
        .onDisappear {
            reviewCoordinator.stopPresenting()
        }
        #endif
        .task(id: loadingAttempt) {
            do {
                try await universeResources.prepare()
                try Task.checkCancellation()
                appEnvironment.destinationsProvider.fetch()
                appEnvironment.featuredObjectProvider.fetch()
                loadingState = .loaded
            } catch is CancellationError {
                return
            } catch {
                loadingState = .failed(error.localizedDescription)
            }
        }
        .animation(.default, value: objectsViewState)
    }

    private var isUniverseVisible: Bool {
        loadingState == .loaded && appEnvironment.currentScreen == .objects
    }

    private var navigationBarTitle: String {
        if isMissionNavigation, let missionFlowState {
            return missionFlowState.mission.title
        }
        return appEnvironment.location
    }

    private var navigationBarSubtitle: String {
        guard isMissionNavigation else { return "" }
        return missionNavigationSubtitle(snapshot: universeResources.navigation.navigationSnapshot)
    }

    private var showsObjectDetailsButton: Bool {
        loadingState == .loaded && appEnvironment.currentScreen == .objects &&
            objectsViewState == .raw && appEnvironment.selectedDestinationID != nil
    }

    @ToolbarContentBuilder
    private var navigationControls: some ToolbarContent {
        if loadingState == .loaded {
            if appEnvironment.currentScreen != .home {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Home", systemImage: "line.3.horizontal.decrease") {
                        appEnvironment.currentScreen = .home
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isMissionNavigation {
                    Button("Cancel mission", systemImage: "xmark") {
                        cancelNavigationAndDismissOverlays()
                    }
                } else {
                    Button("Legal and credits", systemImage: "info.circle") {
                        isShowingLegalCredits = true
                    }
                }
            }
            if showsObjectDetailsButton, let destinationID = appEnvironment.selectedDestinationID {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Object details", systemImage: "binoculars") {
                        makeObjectInfo(selectedDestinationID: destinationID)
                    }
                }
            }
        }
    }

    #if os(iOS)
    private var reviewPresentationContext: ReviewRequestCoordinator.PresentationContext {
        let isObjectInfoPresented: Bool
        if case .info = objectsViewState {
            isObjectInfoPresented = true
        } else {
            isObjectInfoPresented = false
        }
        return .init(isLoaded: loadingState == .loaded,
                     isSceneActive: scenePhase == .active,
                     navigationState: universeResources.navigation.navigationSnapshot.state,
                     isLegalSheetPresented: isShowingLegalCredits,
                     isObjectInfoPresented: isObjectInfoPresented)
    }
    #endif

    private func cancelObjectPresentationModes() {
        universeResources.setObjectInfoOverlayFraming(isPresented: false,
                                                   bottomInset: 0,
                                                   viewportHeight: 0)
        universeResources.transferOrbit.clearTransferOrbit()
        universeResources.navigation.cancelNavigation()
        missionFlowState = nil
        pendingMissionAdvance = nil
        objectsViewState = .raw
    }

    private func startMission(_ mission: Mission) {
        let plan = MissionLaunchPlan(mission: mission)

        missionFlowState = plan.flowState
        pendingMissionAdvance = nil
        appEnvironment.selectedDestinationID = plan.selectedDestinationID
        appEnvironment.selectedPlanet = plan.selectedPlanet
        appEnvironment.currentScreen = plan.screen
        objectsViewState = plan.objectsViewState
        universeResources.navigation.startMission(mission.flightPlan)
    }

    private func handleNavigationSnapshotChange(_ snapshot: NavigationRouteSnapshot) {
        guard objectsViewState == .navigation else { return }

        switch snapshot.state {
        case .completed:
            queueMissionAdvanceIfNeeded(snapshot: snapshot)
        case .cancelled:
            handleNavigationCancelled()
        case .idle, .preparing, .running, .failed:
            break
        }
    }

    private func queueMissionAdvanceIfNeeded(snapshot: NavigationRouteSnapshot) {
        guard pendingMissionAdvance == nil,
              let flowState = missionFlowState else {
            return
        }

        let advance = flowState.handleCompletedNavigation(originName: snapshot.originName,
                                                          waypointName: snapshot.waypointName,
                                                          destinationName: snapshot.destinationName,
                                                          missionID: snapshot.mission)
        guard advance != .noChange else { return }

        missionFlowState = flowState
        pendingMissionAdvance = advance
    }

    private func handleNavigationCancelled() {
        if let pendingMissionAdvance {
            self.pendingMissionAdvance = nil
            switch pendingMissionAdvance {
            case .complete:
                missionFlowState = nil
                appEnvironment.selectedPlanet = nil
                objectsViewState = .raw
            case .noChange:
                break
            }
            return
        }

        missionFlowState = nil
        objectsViewState = .raw
    }
}

private struct UniverseLoadingFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(OptiColor.overlayTextPrimary)

            VStack(spacing: 8) {
                Text("Unable to Load Universe")
                    .font(Typography.screenTitle)
                    .foregroundStyle(OptiColor.textPrimary)
                Text(message)
                    .font(Typography.overlayBody)
                    .foregroundStyle(OptiColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retry) {
                NeonButtonView(title: "Try Again")
            }
            .buttonStyle(NeonButtonStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OptiColor.screenBackground)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    RootContainerView(universeResources: UniverseModuleFactory.makeResources())
        .environment(AppEnvironment())
        .environment(ReviewRequestCoordinator(defaults: UserDefaults(suiteName: "OptiUniverse.ReviewPreview")!))
}
