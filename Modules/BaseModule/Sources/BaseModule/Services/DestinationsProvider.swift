//
//  DestinationsProvider.swift
//  OptiUniverse
//
//  Created by max on 28.04.2026.
//

import Foundation
internal import CommonTools

actor DestinationsProvider: DestinationsProviderProtocol {

    enum Constants {
        static let filename = "DestinationObjects"
        static let urlString = "https://api.kb404.com/static/DestinationObjects.json"
    }


    var destinations: [DestinationObject] = []
    private var inFlightTask: Task<(), Never>?

    func fetch() async {
        guard destinations.isEmpty else { return }
        if let inFlightTask { return await inFlightTask.value }

        inFlightTask = Task {
            let destinations = try? await [DestinationObject]
                .loadFromRemoteConfig(from: Constants.urlString)

            if let destinations, !destinations.isEmpty {
                self.destinations = destinations
            } else {
                self.destinations = Bundle.main.loadConfig(filename: Constants.filename)
            }

            inFlightTask = nil
        }
        await inFlightTask?.value
    }
}
