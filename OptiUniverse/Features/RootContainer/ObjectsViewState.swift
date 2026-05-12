//
//  ObjectsViewState.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import MetalModule

enum ObjectsViewState: Equatable {
    case raw
    case orbit(TransferOrbitSummary)
    case info(ObjectInfoViewEntity)
    case navigation

    static func == (lhs: ObjectsViewState, rhs: ObjectsViewState) -> Bool {
        switch (lhs, rhs) {
        case (.raw, .raw):
            true
        case (.navigation, .navigation):
            true
        case let (.orbit(lhsSummary), .orbit(rhsSummary)):
            lhsSummary == rhsSummary
        case let (.info(lhsEntity), .info(rhsEntity)):
            lhsEntity.id == rhsEntity.id
        default:
            false
        }
    }
}
