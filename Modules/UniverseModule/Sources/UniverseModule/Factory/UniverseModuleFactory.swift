//
//  UniverseModuleFactory.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public enum UniverseModuleFactory {
    public static func makeResources() -> UniverseModuleResources {
        UniverseModuleResources()
    }
}
