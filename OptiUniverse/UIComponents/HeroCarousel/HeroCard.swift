//
//  HeroCard.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI
import BaseModule

struct HeroCard: Identifiable, Equatable {
    let id: UUID
    let imageResource: ImageResource
    let title: String
    let subtitle: String
    let accentColors: [Color]
    let surfaceLocation: SurfaceLocation?

    init(id: UUID,
         imageResource: ImageResource,
         title: String,
         subtitle: String,
         accentColors: [Color],
         surfaceLocation: SurfaceLocation? = nil) {
        self.id = id
        self.imageResource = imageResource
        self.title = title
        self.subtitle = subtitle
        self.accentColors = accentColors
        self.surfaceLocation = surfaceLocation
    }

    var followTarget: ObjectFollowTarget {
        ObjectFollowTarget(bodyName: surfaceLocation?.bodyName ?? title,
                           surfaceLocation: surfaceLocation)
    }
}
