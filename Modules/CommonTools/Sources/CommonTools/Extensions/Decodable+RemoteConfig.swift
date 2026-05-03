//
//  Decodable+RemoteConfig.swift
//  CommonTools
//
//  Created by max on 03.05.2026.
//

import Foundation

public extension Decodable {

    static func loadFromRemoteConfig(from path: String) async throws -> Self {
        guard let url = URL(string: path) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Self.self, from: data)
    }
}
