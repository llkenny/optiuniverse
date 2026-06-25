//
//  SurfaceCoordinateDebugLogger.swift
//  UniverseModule
//
//  Created by Codex on 06.06.2026.
//

import os
import simd

final class SurfaceCoordinateDebugLogger {
    private let logger = Logger(subsystem: "OptiUniverse.UniverseModule",
                                category: "SurfaceCoordinates")
    private let minimumFrameInterval: UInt64
    private var lastLoggedFrameIDByBody: [String: UInt64] = [:]

    init(minimumFrameInterval: UInt64 = 30) {
        self.minimumFrameInterval = minimumFrameInterval
    }

    func logIfNeeded(bodyName: String,
                     planet: CelestialBodySnapshot,
                     snapshot: UniverseSceneSnapshot,
                     cameraSnapshot: SnapshotProvider.CameraSnapshot) {
        guard shouldLog(bodyName: bodyName,
                        frameID: snapshot.frameID) else {
            return
        }

        guard let hit = SurfaceCoordinateMath.centerRayIntersection(
            cameraWorldPosition: cameraSnapshot.cameraWorldPosition,
            cameraTarget: cameraSnapshot.sceneOrigin,
            planet: planet
        ), let coordinate = SurfaceCoordinateMath.coordinate(on: planet,
                                                             forWorldPoint: hit.worldPoint) else {
            return
        }

        lastLoggedFrameIDByBody[bodyName] = snapshot.frameID
        logger.debug(
            """
            Surface coordinate body=\(bodyName, privacy: .private) \
            latitude=\(coordinate.latitudeDegrees, privacy: .private) \
            longitude=\(coordinate.longitudeDegrees, privacy: .private) \
            frameID=\(snapshot.frameID, privacy: .public) \
            simulationTime=\(snapshot.simulationTime, privacy: .public)
            """
        )
    }

    private func shouldLog(bodyName: String,
                           frameID: UInt64) -> Bool {
        guard let lastLoggedFrameID = lastLoggedFrameIDByBody[bodyName],
              frameID >= lastLoggedFrameID else {
            return true
        }

        return frameID - lastLoggedFrameID >= minimumFrameInterval
    }
}
