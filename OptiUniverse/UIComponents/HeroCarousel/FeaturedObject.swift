//
//  FeaturedObject.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import Foundation

struct FeaturedObject: Decodable {
    struct AccentColor: Decodable {
        let r: Double
        let g: Double
        let b: Double
    }
    
    let id: UUID
    let name: String
    let description: String
    let imageName: String
    let accentColor: [AccentColor]
}
