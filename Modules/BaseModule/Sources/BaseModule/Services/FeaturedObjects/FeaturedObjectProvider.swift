//
//  FeaturedObjectProvider.swift
//  BaseModule
//
//  Created by max on 05.05.2026.
//

import Foundation
internal import CommonTools

final class FeaturedObjectProvider: FeaturedObjectProviderProtocol {

    enum Constants {
        static let filename = "FeaturedObjects"
    }

    private(set) var featuredObjects: [FeaturedObject] = []

    func fetch() {
        guard featuredObjects.isEmpty else { return }
        featuredObjects = Bundle.main.loadConfig(filename: Constants.filename)
    }
}
