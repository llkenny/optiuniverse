//
//  UniverseModuleResourcesProtocol.swift
//  UniverseModule
//
//  Created by Codex on 27.06.2026.
//

import CoreGraphics

@MainActor
public protocol UniverseModuleResourcesProtocol: AnyObject {
    var navigation: any UniverseNavigationControlling { get }
    var transferOrbit: any UniverseTransferOrbitControlling { get }

    func rotateCamera(translation: CGSize, velocity: CGSize)
    func scaleCamera(by scale: Float, velocity: CGFloat)
    func adjustImmersiveFocusRotation(translation: CGSize) -> Bool
    func adjustImmersiveFocusScale(by scale: Float) -> Bool
    func setObjectInfoOverlayFraming(isPresented: Bool,
                                     bottomInset: CGFloat,
                                     viewportHeight: CGFloat)
}

extension UniverseModuleResources: UniverseModuleResourcesProtocol {}
