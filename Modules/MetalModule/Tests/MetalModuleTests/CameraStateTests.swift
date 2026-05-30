import simd
import Testing
@testable import MetalModule

@Test func cameraStateCommitRecordsDirtyFieldsAndIncrementsRevisionOnce() {
    let cameraState = CameraState()
    let orientation = simd_quatf(angle: 0.25,
                                 axis: SIMD3<Float>(0, 1, 0))

    let dirtyFields = cameraState.commit(CameraState.Transaction(
        cameraTarget: SIMD3<Float>(1, 2, 3),
        cameraDistance: 4,
        cameraOrientation: orientation
    ))

    #expect(dirtyFields == [.target, .distance, .orientation])
    #expect(cameraState.lastDirtyFields == [.target, .distance, .orientation])
    #expect(cameraState.revision == 1)
}

@Test func cameraStateUnchangedCommitDoesNotIncrementRevision() {
    let cameraState = CameraState()
    let initialRevision = cameraState.revision

    let dirtyFields = cameraState.commit(CameraState.Transaction(
        cameraTarget: cameraState.cameraTarget,
        cameraDistance: cameraState.cameraDistance,
        cameraOrientation: cameraState.cameraOrientation
    ))

    #expect(dirtyFields.isEmpty)
    #expect(cameraState.lastDirtyFields.isEmpty)
    #expect(cameraState.revision == initialRevision)
}

@Test func cameraStateNormalizesCommittedOrientation() {
    let cameraState = CameraState()
    let orientation = simd_quatf(vector: SIMD4<Float>(0, 0.5, 0, 0.5))

    cameraState.commit(CameraState.Transaction(cameraOrientation: orientation))

    #expect(abs(simd_length(cameraState.cameraOrientation.vector) - 1) < 0.000001)
}

@Test func cameraStateDistanceConstraintCommitsOnlyWhenDistanceChanges() {
    let cameraState = CameraState()
    cameraState.commit(CameraState.Transaction(cameraDistance: 0.1))
    let revisionBeforeClamp = cameraState.revision

    let dirtyFields = cameraState.enforceCameraConstraints(minDistance: 0.5)
    let revisionAfterClamp = cameraState.revision
    let unchangedDirtyFields = cameraState.enforceCameraConstraints(minDistance: 0.5)

    #expect(dirtyFields == [.distance])
    #expect(cameraState.cameraDistance == 0.5)
    #expect(revisionAfterClamp == revisionBeforeClamp + 1)
    #expect(unchangedDirtyFields.isEmpty)
    #expect(cameraState.revision == revisionAfterClamp)
}
