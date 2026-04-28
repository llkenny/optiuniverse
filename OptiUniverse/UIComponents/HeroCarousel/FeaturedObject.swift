//
//  FeaturedObject.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import Foundation

struct FeaturedObject: Decodable {
    // swiftlint:disable identifier_name
    struct AccentColor: Decodable {
        let r: Double
        let g: Double
        let b: Double
    }
    // swiftlint:enable identifier_name

    let id: UUID
    let name: String
    let description: String
    let imageName: String
    let accentColor: [AccentColor]
}
