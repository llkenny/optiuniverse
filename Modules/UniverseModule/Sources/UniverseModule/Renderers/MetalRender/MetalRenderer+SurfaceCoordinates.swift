//
//  MetalRenderer+SurfaceCoordinates.swift
//  UniverseModule
//
//  Created by Codex on 06.06.2026.
//

extension MetalRenderer {
    func logSurfaceCoordinateDebug(snapshot: PreparedRenderSnapshot?,
                                   cameraSnapshot: SnapshotProvider.CameraSnapshot,
                                   modeState: CameraFrameModeState) {
        guard let snapshot,
              let bodyName = surfaceCoordinateDebugTargetName(cameraSnapshot: cameraSnapshot,
                                                              modeState: modeState),
              let planet = snapshot.planet(named: bodyName) else {
            return
        }

        surfaceCoordinateDebugLogger.logIfNeeded(bodyName: bodyName,
                                                 planet: planet,
                                                 snapshot: snapshot,
                                                 cameraSnapshot: cameraSnapshot)
    }

    private func surfaceCoordinateDebugTargetName(cameraSnapshot: SnapshotProvider.CameraSnapshot,
                                                  modeState: CameraFrameModeState) -> String? {
        if modeState.navigationControlsCamera,
           let destinationName = modeState.navigation?.destinationName {
            return destinationName
        }

        return cameraSnapshot.dependencies.followedObject?.planetName
    }
}
