//
//  DestinationsProvider.swift
//  OptiUniverse
//
//  Created by max on 28.04.2026.
//

import Foundation
internal import CommonTools

final class DestinationsProvider: DestinationsProviderProtocol {

    enum Constants {
        static let filename = "DestinationObjects"
    }

    private(set) var destinations: [DestinationObject] = []

    func fetch() {
        guard destinations.isEmpty else { return }
        destinations = Bundle.main.loadConfig(filename: Constants.filename)
    }
}
