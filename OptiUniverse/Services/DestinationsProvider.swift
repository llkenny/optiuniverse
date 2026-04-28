//
//  DestinationsProvider.swift
//  OptiUniverse
//
//  Created by max on 28.04.2026.
//

import Foundation

actor DestinationsProvider: DestinationsProviderProtocol {
    var destinations: [DestinationObject] = []
    private var inFlightTask: Task<(), Never>?
    
    func fetch() async {
        guard destinations.isEmpty else { return }
        if inFlightTask == nil {
            inFlightTask = Task {
                destinations = Bundle.main.loadConfig(filename: "DestinationObjects")
                inFlightTask = nil
            }
        }
        await inFlightTask?.value
    }
}
