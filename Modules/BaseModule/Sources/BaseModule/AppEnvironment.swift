//
//  AppEnvironment.swift
//  OptiUniverse
//
//  Created by Codex on 08.04.2026.
//

import Observation

@Observable
public final class AppEnvironment {

    public enum Screen {
        case home, objects
    }

    public var currentScreen: Screen = .home
    public var selectedPlanet: String?
    public var location: String {
        "\(selectedPlanet ?? "Unknown"), Solar System, Milky Way"
    }

    public let destinationsProvider: DestinationsProviderProtocol = DestinationsProvider()

    public init() {
    }
}
