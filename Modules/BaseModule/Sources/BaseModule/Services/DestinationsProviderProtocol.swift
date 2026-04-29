//
//  DestinationsProviderProtocol.swift
//  OptiUniverse
//
//  Created by max on 28.04.2026.
//

public protocol DestinationsProviderProtocol: Actor {
    var destinations: [DestinationObject] { get }
    func fetch() async
}
