//
//  MetalModuleAssets.swift
//  MetalModule
//
//  Created by Codex on 08.06.2026.
//

import Foundation

enum MetalModuleAssets {
    static func milkyWayEnvironmentURL() -> URL? {
        Bundle.module.url(forResource: "milky_way_environment",
                          withExtension: "jpg") ??
        Bundle.module.url(forResource: "milky_way_environment",
                          withExtension: "jpg",
                          subdirectory: "Assets/Environment")
    }
}
