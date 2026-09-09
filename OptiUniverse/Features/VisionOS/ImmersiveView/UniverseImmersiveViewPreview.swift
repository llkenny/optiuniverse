//
//  UniverseImmersiveViewPreview.swift
//  OptiUniverse
//
//  Created by max on 27.06.2026.
//

#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

private final class UniverseImmersivePreviewResources: UniverseModuleResourcesProtocol {
    let navigation: any UniverseNavigationControlling = UniverseImmersivePreviewNavigation()
    let transferOrbit: any UniverseTransferOrbitControlling = UniverseImmersivePreviewTransferOrbit()

    func rotateCamera(translation: CGSize, velocity: CGSize) {}
    func scaleCamera(by scale: Float, velocity: CGFloat) {}
    func adjustImmersiveFocusRotation(translation: CGSize) -> Bool { false }
    func adjustImmersiveFocusScale(by scale: Float) -> Bool { false }
    func setObjectInfoOverlayFraming(isPresented: Bool,
                                     bottomInset: CGFloat,
                                     viewportHeight: CGFloat) {}
}

private final class UniverseImmersivePreviewNavigation: UniverseNavigationControlling {
    let navigationSnapshot: NavigationRouteSnapshot = .idle

    func startNavigation(from originName: String, via waypointName: String?, to destinationName: String) {}
    func startNavigation(from originName: String, to destinationName: String) {}
    func startNavigation(to name: String) {}
    func pauseNavigation() {}
    func resumeNavigation() {}
    func cancelNavigation() {}
    func doneNavigation() {}
}

private final class UniverseImmersivePreviewTransferOrbit: UniverseTransferOrbitControlling {
    func showTransferOrbit(to destinationName: String) {}
    func clearTransferOrbit() {}
}

private struct UniverseImmersivePreviewScene: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.0, green: 0.0, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.97, green: 0.42, blue: 0.2),
                            Color(red: 0.36, green: 0.08, blue: 0.04),
                            .black.opacity(0)
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 210
                    )
                )
                .frame(width: 360, height: 360)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        }
    }
}

#Preview("Immersive Universe") {
    let appEnvironment = AppEnvironment()
    appEnvironment.destinationsProvider.fetch()
    let destination = appEnvironment.destinationsProvider.destinations.first {
        $0.object == "Mars"
    }
    appEnvironment.selectedDestinationID = destination?.id
    appEnvironment.selectedPlanet = destination?.object ?? "Mars"
    appEnvironment.isUniverseImmersivePresented = true

    return UniverseImmersiveView(resources: UniverseImmersivePreviewResources()) { _ in
        UniverseImmersivePreviewScene()
    }
    .environment(appEnvironment)
}
#endif
