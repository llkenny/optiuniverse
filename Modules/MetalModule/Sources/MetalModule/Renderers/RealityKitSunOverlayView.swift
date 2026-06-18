//
//  RealityKitSunOverlayView.swift
//  MetalModule
//
//  Created by Codex on 12.06.2026.
//

import Foundation
import RealityKit
import simd
import UIKit

@MainActor
final class RealityKitSunOverlayView: UIView {
    private enum Constants {
        static let resourceName = "RCP_Sun_Scene"
        static let bodyName = "Body"
        static let defaultVerticalFieldOfView: Float = .pi / 3
        static let minimumSourceRadius: Float = 0.0001
        static let fallbackSourceRadius: Float = 0.1
    }

    private let arView: ARView
    private let worldAnchor = AnchorEntity(world: .zero)
    private let sunRoot = Entity()
    private var sourceBodyRadius: Float?
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        arView = ARView(frame: .zero,
                        cameraMode: .nonAR,
                        automaticallyConfigureSession: false)
        super.init(frame: frame)

        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false

        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.isOpaque = false
        arView.backgroundColor = .clear
        arView.isUserInteractionEnabled = false
        arView.environment.background = .color(.clear)
        arView.renderOptions = [
            .disableCameraGrain,
            .disableGroundingShadows,
            .disableMotionBlur,
            .disableDepthOfField,
            .disableAREnvironmentLighting
        ]

        addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: topAnchor),
            arView.bottomAnchor.constraint(equalTo: bottomAnchor),
            arView.leadingAnchor.constraint(equalTo: leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        sunRoot.isEnabled = false
        worldAnchor.addChild(sunRoot)
        arView.scene.addAnchor(worldAnchor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    func update(cameraSnapshot: SnapshotProvider.CameraSnapshot,
                renderSnapshot: PreparedRenderSnapshot?) {
        loadSunIfNeeded()

        guard let sourceBodyRadius,
              let sun = renderSnapshot?.planet(named: "Sun") else {
            sunRoot.isEnabled = false
            return
        }

        let localizedPosition = sun.worldPosition - cameraSnapshot.sceneOrigin
        let cameraPosition = cameraSnapshot.renderViewMatrix
            * SIMD4<Float>(localizedPosition, 1)
        guard cameraPosition.z > cameraSnapshot.dependencies.projection.nearPlane else {
            sunRoot.isEnabled = false
            return
        }

        let verticalFieldOfView = cameraSnapshot.dependencies.projection.verticalFieldOfView
        let fieldOfViewScale = tan(Constants.defaultVerticalFieldOfView * 0.5)
            / tan(verticalFieldOfView * 0.5)
        let scale = max((sun.framingRadius / sourceBodyRadius) * fieldOfViewScale, 0)
        sunRoot.position = SIMD3<Float>(cameraPosition.x * fieldOfViewScale,
                                       cameraPosition.y * fieldOfViewScale,
                                       -cameraPosition.z)
        sunRoot.scale = SIMD3<Float>(repeating: scale)
        sunRoot.isEnabled = true
    }

    func dismantle() {
        loadTask?.cancel()
        loadTask = nil
        arView.scene.anchors.removeAll()
    }

    private func loadSunIfNeeded() {
        guard sourceBodyRadius == nil, loadTask == nil else { return }

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { loadTask = nil }

            guard let url = Bundle.module.url(forResource: Constants.resourceName,
                                              withExtension: "usdz") else {
                assertionFailure("RealityKit Sun resource not found")
                return
            }

            do {
                let assetRoot = try await Entity(contentsOf: url)
                guard let body = assetRoot.findEntity(named: Constants.bodyName) else {
                    assertionFailure("RealityKit Sun Body entity not found")
                    return
                }

                configureVisibility(root: assetRoot, body: body)
                let bounds = body.visualBounds(recursive: true,
                                               relativeTo: assetRoot,
                                               excludeInactive: true)
                let maximumExtent = max(bounds.extents.x,
                                        bounds.extents.y,
                                        bounds.extents.z)
                let measuredRadius = maximumExtent * 0.5
                let radius = measuredRadius.isFinite && measuredRadius > Constants.minimumSourceRadius
                    ? measuredRadius
                    : Constants.fallbackSourceRadius
                assetRoot.position = -bounds.center
                sunRoot.addChild(assetRoot)
                sourceBodyRadius = radius
            } catch {
                assertionFailure("RealityKit Sun load failed: \(error)")
            }
        }
    }

    @discardableResult
    private func configureVisibility(root: Entity,
                                     body: Entity,
                                     current: Entity? = nil,
                                     insideBody: Bool = false) -> Bool {
        let entity = current ?? root
        let isBody = entity === body
        let shouldKeepDescendants = insideBody || isBody
        var containsBody = isBody

        for child in entity.children {
            containsBody = configureVisibility(root: root,
                                               body: body,
                                               current: child,
                                               insideBody: shouldKeepDescendants) || containsBody
        }

        entity.isEnabled = entity === root || shouldKeepDescendants || containsBody
        return containsBody
    }
}
