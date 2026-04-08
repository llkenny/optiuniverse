//
//  Bundle+Config.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import Foundation

extension Bundle {
    
    func loadConfig<T: Decodable>(filename: String) -> [T] {
        guard let url = self.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([T].self, from: data) else {
            return []
        }
        return configs
    }
}
