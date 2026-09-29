import simd

public enum TransferPreviewStatus: Sendable, Equatable {
    case inactive
    case preparing
    case ready
    case failed(TransferFailure)
}

public struct TransferPreviewSnapshot: Sendable, Equatable {
    public var status: TransferPreviewStatus = .inactive
    public var destinationName: String?
    public var physicalFlightDuration: Double?
    public static let inactive = TransferPreviewSnapshot()
}

struct TransferOrbitRenderState: Equatable {
    let transferOrbit: TransferSolution?
    var earthOrbitPoints: [SIMD3<Float>] = []
    var destinationOrbitPoints: [SIMD3<Float>] = []
    static let inactive = TransferOrbitRenderState(transferOrbit: nil)
}
