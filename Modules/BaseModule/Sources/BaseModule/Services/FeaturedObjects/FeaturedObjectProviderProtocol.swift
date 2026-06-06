//
//  FeaturedObjectProviderProtocol.swift
//  BaseModule
//
//  Created by max on 05.05.2026.
//

public protocol FeaturedObjectProviderProtocol: AnyObject {
    var featuredObjects: [FeaturedObject] { get }
    func fetch()
}
