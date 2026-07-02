//
//  NavigationRouteRenderState.swift
//  UniverseModule
//
//  Created by max on 25.06.2026.
//

import Foundation

struct NavigationRouteRenderState: Equatable {
    let route: NavigationRoute?
    let progress: Float
    let elapsedTime: TimeInterval

    static let idle = NavigationRouteRenderState(route: nil,
                                                 progress: 0,
                                                 elapsedTime: 0)
}
