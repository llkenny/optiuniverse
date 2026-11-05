//
//  ObjectsViewState.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import UniverseModule

enum ObjectsViewState: Equatable {
    case raw
    case orbit
    case info(ObjectInfoViewEntity)
    case navigation

    static func == (lhs: ObjectsViewState, rhs: ObjectsViewState) -> Bool {
        switch (lhs, rhs) {
        case (.raw, .raw):
            true
        case (.navigation, .navigation):
            true
        case (.orbit, .orbit):
            true
        case let (.info(lhsEntity), .info(rhsEntity)):
            lhsEntity.id == rhsEntity.id
        default:
            false
        }
    }
}
