//
//  CategoryChipsViewModel.swift
//  OptiUniverse
//
//  Created by max on 21.04.2026.
//

import Observation
import BaseModule

@Observable
final class CategoryChipsViewModel {
    var tags: [String] = []
    var destinationsProvider: DestinationsProviderProtocol?

    func loadTags() async {
        let tags: [String] = await destinationsProvider?
            .destinations
            .map { $0.tag } ?? []
        var seenTags = Set<String>()
        self.tags = tags.filter { seenTags.insert($0).inserted }
    }
}
