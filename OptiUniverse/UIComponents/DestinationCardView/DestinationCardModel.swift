//
//  DestinationCardModel.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import DeveloperToolsSupport
import Foundation
import BaseModule

struct DestinationCardModel: Identifiable {
    let id: UUID
    let object: String
    let title: String
    let subtitle: String
    let imageResource: ImageResource
    let tag: String
    let surfaceLocation: SurfaceLocation?

    init(id: UUID,
         object: String,
         title: String,
         subtitle: String,
         imageResource: ImageResource,
         tag: String,
         surfaceLocation: SurfaceLocation? = nil) {
        self.id = id
        self.object = object
        self.title = title
        self.subtitle = subtitle
        self.imageResource = imageResource
        self.tag = tag
        self.surfaceLocation = surfaceLocation
    }

    var followTarget: ObjectFollowTarget {
        ObjectFollowTarget(bodyName: surfaceLocation?.bodyName ?? object,
                           surfaceLocation: surfaceLocation)
    }
}
