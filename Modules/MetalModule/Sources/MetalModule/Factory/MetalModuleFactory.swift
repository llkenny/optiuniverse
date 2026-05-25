//
//  MetalModuleFactory.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public enum MetalModuleFactory {
    public static func makeResources() -> MetalModuleResources {
        MetalModuleResources()
    }
}
