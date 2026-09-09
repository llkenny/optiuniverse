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

struct RootContainerView: View {

    private enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Environment(AppEnvironment.self) var appEnvironment
    @State private var loadingState: LoadingState = .loading
    @State private var loadingAttempt = 0
    @State var missionFlowState: MissionFlowState?
    @State var pendingMissionAdvance: MissionFlowAdvance?
    @State var objectsViewState: ObjectsViewState = .raw
    @State var objectInfoOverlayPresentationID = UUID() // Force makeInfoOverlay recreation for animation stability
    @GestureState var objectInfoDragOffset: CGFloat = 0
    let universeResources: UniverseModuleResources

    init(universeResources: UniverseModuleResources) {
        self.universeResources = universeResources
    }

    var body: some View {
        ZStack {
            OptiColor.screenBackground
                .ignoresSafeArea()

            switch loadingState {
            case .loaded:
                VStack(spacing: 0) {
                    TopBarView()
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                    ZStack {
                        UniverseView(
                            resources: universeResources,
                            isActive: appEnvironment.currentScreen == .objects
                        )
                            .ignoresSafeArea(edges: .bottom)
                            .opacity(appEnvironment.currentScreen == .objects ? 1 : 0)
                            .allowsHitTesting(appEnvironment.currentScreen == .objects)

                        switch appEnvironment.currentScreen {
                        case .home:
                            HomeView(onMissionSelected: startMission)
                                .transition(.opacity)
                        case .objects:
                            switch objectsViewState {
                            case .raw:
                                if let selectedDestinationID = appEnvironment.selectedDestinationID {
                                    makeInfoButton(selectedDestinationID: selectedDestinationID)
                                }
                            case .orbit:
                                makeOrbitBackButton()
                                if let selectedDestinationID = appEnvironment.selectedDestinationID {
                                    makeStartNavigationButton(destinationID: selectedDestinationID)
                                }
                            case .navigation:
                                makeNavigationControls(snapshot: universeResources.navigation.navigationSnapshot)
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .onAppear {
                        objectsViewState = .raw
                    }
                }
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
            objectsViewState = .raw
        }
        .onChange(of: universeResources.navigation.navigationSnapshot) { _, snapshot in
            handleNavigationSnapshotChange(snapshot)
        }
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
        .overlay(alignment: .bottom) {
            if case .info(let selectedObjectInfo) = objectsViewState {
                makeInfoOverlay(entity: selectedObjectInfo)
                    .id(objectInfoOverlayPresentationID)
            }
        }
        .animation(.default, value: objectsViewState)
        .animation(.default, value: objectInfoOverlayPresentationID)
    }

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
        let route = plan.route

        missionFlowState = plan.flowState
        pendingMissionAdvance = nil
        appEnvironment.selectedDestinationID = plan.selectedDestinationID
        appEnvironment.selectedPlanet = plan.selectedPlanet
        appEnvironment.currentScreen = plan.screen
        objectsViewState = plan.objectsViewState
        universeResources.navigation.startNavigation(from: route.originName,
                                                     via: route.waypointName,
                                                     to: route.destinationName)
    }

    private func handleNavigationSnapshotChange(_ snapshot: NavigationRouteSnapshot) {
        guard objectsViewState == .navigation else { return }

        switch snapshot.state {
        case .completed:
            queueMissionAdvanceIfNeeded(snapshot: snapshot)
        case .cancelled:
            handleNavigationCancelled()
        case .idle, .preparing, .running, .paused:
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
                                                          destinationName: snapshot.destinationName)
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
}
