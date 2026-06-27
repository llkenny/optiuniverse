//
//  VisionImmersiveControlsPreview.swift
//  OptiUniverse
//
//  Created by max on 27.06.2026.
//

#if os(visionOS)
import UniverseModule
import BaseModule
import SwiftUI

private final class VisionImmersiveControlsPreviewResources: UniverseModuleResourcesProtocol {
    let navigation: any UniverseNavigationControlling = VisionImmersiveControlsPreviewNavigation()
    let transferOrbit: any UniverseTransferOrbitControlling = PreviewTransferOrbit()

    func rotateCamera(translation: CGSize, velocity: CGSize) {}
    func scaleCamera(by scale: Float, velocity: CGFloat) {}
    func adjustImmersiveFocusRotation(translation: CGSize) -> Bool { false }
    func adjustImmersiveFocusScale(by scale: Float) -> Bool { false }
    func setObjectInfoOverlayFraming(isPresented: Bool,
                                     bottomInset: CGFloat,
                                     viewportHeight: CGFloat) {}
}

private final class VisionImmersiveControlsPreviewNavigation: UniverseNavigationControlling {
    let navigationSnapshot: NavigationRouteSnapshot = .idle
    let navigationCameraFollowEnabled = true

    func startNavigation(to name: String) {}
    func pauseNavigation() {}
    func resumeNavigation() {}
    func cancelNavigation() {}
    func doneNavigation() {}
    func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {}
}

private final class PreviewTransferOrbit: UniverseTransferOrbitControlling {
    func showTransferOrbit(to destinationName: String) {}
    func clearTransferOrbit() {}
}

private enum VisionImmersiveControlsPreviewData {
    static let destination: DestinationObject = {
        let data = Data("""
        {
          "id": "2530E63D-699E-4F38-9B77-EABDE51152A5",
          "object": "Mars",
          "title": "Mars",
          "subtitle": "Red Planet",
          "description": "Dusty world.",
          "imageName": "dst-Mars",
          "tag": "Hot",
          "isNavigable": true,
          "details": [
            { "title": "Age", "value": "4.5B", "dimension": "YEARS" }
          ]
        }
        """.utf8)

        do {
            return try JSONDecoder().decode(DestinationObject.self, from: data)
        } catch {
            fatalError("Invalid VisionImmersiveControls preview destination: \(error)")
        }
    }()
}

#Preview("Selected Destination") {
    let appEnvironment = AppEnvironment()
    appEnvironment.selectedPlanet = "Mars"

    return VisionImmersiveControls(
        resources: VisionImmersiveControlsPreviewResources(),
        selectedDestination: VisionImmersiveControlsPreviewData.destination,
        showObjectInfo: { _ in },
        exit: {}
    )
    .environment(appEnvironment)
    .padding()
    .background(.black)
}
#endif
