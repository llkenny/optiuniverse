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
    let isCameraAutoFramingEnabled: Bool
    let starshipFlight: StarshipFlightState?
    let crew13Flight: Crew13FlightState?

    /// Camera tracking and visible vehicles must share the exact elapsed-time sample, not a Float progress round-trip.
    var preciseMarkerPosition: SIMD3<Double>? {
        crew13Flight?.dragon.precisePosition ?? starshipFlight?.ship.precisePosition ?? route?.precisePoint(at: progress)
    }

    static let idle = NavigationRouteRenderState(route: nil,
                                                 progress: 0,
                                                 elapsedTime: 0,
                                                 isCameraAutoFramingEnabled: false)

    init(route: NavigationRoute?,
         progress: Float,
         elapsedTime: TimeInterval,
         isCameraAutoFramingEnabled: Bool = true) {
        starshipFlight = route?.starshipProfile?.sample(time: elapsedTime)
        crew13Flight = route?.crew13Profile?.sample(time: elapsedTime)
        self.route = route
        self.progress = progress
        self.elapsedTime = elapsedTime
        self.isCameraAutoFramingEnabled = isCameraAutoFramingEnabled
    }
}
