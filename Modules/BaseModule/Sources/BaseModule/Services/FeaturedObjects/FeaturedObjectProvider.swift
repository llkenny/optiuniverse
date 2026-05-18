//
//  FeaturedObjectProvider.swift
//  BaseModule
//
//  Created by max on 05.05.2026.
//

import Foundation
internal import CommonTools

actor FeaturedObjectProvider: FeaturedObjectProviderProtocol {

    enum Constants {
        static let filename = "FeaturedObjects"
        static let urlString = "https://llkenny.github.io/optiuniverse/static/FeaturedObjects.json"
    }

    var featuredObjects: [FeaturedObject] = []
    private var inFlightTask: Task<(), Never>?

    func fetch() async {
        guard featuredObjects.isEmpty else { return }
        if let inFlightTask { return await inFlightTask.value }

        inFlightTask = Task {
            await self.fetchObjects()

            inFlightTask = nil
        }

        await inFlightTask?.value
    }

    private func fetchObjects() async {
        let featuredObjects: [FeaturedObject]

        let remoteObjects = try? await [FeaturedObject]
            .loadFromRemoteConfig(from: Constants.urlString)

        if let remoteObjects, !remoteObjects.isEmpty {
            featuredObjects = remoteObjects
        } else {
            featuredObjects = Bundle.main.loadConfig(filename: Constants.filename)
        }

        self.featuredObjects = featuredObjects
    }
}
