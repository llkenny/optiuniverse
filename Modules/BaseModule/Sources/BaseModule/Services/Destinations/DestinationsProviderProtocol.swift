//
//  DestinationsProviderProtocol.swift
//  OptiUniverse
//
//  Created by max on 28.04.2026.
//

public protocol DestinationsProviderProtocol: AnyObject {
    var destinations: [DestinationObject] { get }
    func fetch()
}
