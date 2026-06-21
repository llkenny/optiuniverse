import Foundation
import Metal
import OSLog
import RealityKit

struct FilmicPostProcessEffect: PostProcessEffect {
    private let renderer = FilmicPostProcessRenderer()

    nonisolated mutating func prepare(for device: any MTLDevice) {
        renderer.prepare(for: device)
    }

    nonisolated mutating func postProcess(
        context: borrowing PostProcessEffectContext<any MTLCommandBuffer>
    ) {
        renderer.encode(
            commandBuffer: context.commandBuffer,
            sourceTexture: context.sourceColorTexture,
            targetTexture: context.targetColorTexture
        )
    }
}

final class FilmicPostProcessRenderer: @unchecked Sendable {
    private enum PipelineKind: Hashable {
        case filmic
        case passthrough
    }

    private struct PipelineKey: Hashable {
        let pixelFormat: MTLPixelFormat
        let kind: PipelineKind
    }

    private let lock = NSLock()
    private let libraryLoader: @Sendable (any MTLDevice) -> MTLLibrary?
    private let logger = Logger(
        subsystem: "OptiUniverse.UniverseModule",
        category: "PostProcessing"
    )
    private var library: MTLLibrary?
    private var pipelines: [PipelineKey: MTLRenderPipelineState] = [:]
    private var failedPipelineKeys: Set<PipelineKey> = []
    private var preparationError: String?
    private var hasLoggedFailure = false
    private(set) var pipelineCreationCount = 0

    init(
        libraryLoader: @escaping @Sendable (any MTLDevice) -> MTLLibrary? = { device in
            try? device.makeDefaultLibrary(bundle: .module)
        }
    ) {
        self.libraryLoader = libraryLoader
    }

    func prepare(for device: any MTLDevice) {
        lock.lock()
        defer { lock.unlock() }

        if let loadedLibrary = libraryLoader(device) {
            library = loadedLibrary
            preparationError = nil
            pipelines.removeAll(keepingCapacity: true)
            failedPipelineKeys.removeAll(keepingCapacity: true)
        } else {
            library = nil
            preparationError = "Unable to load the UniverseModule Metal library"
        }
    }

    func encode(
        commandBuffer: any MTLCommandBuffer,
        sourceTexture: any MTLTexture,
        targetTexture: any MTLTexture
    ) {
        if let pipeline = pipeline(
            for: targetTexture.pixelFormat,
            kind: .filmic,
            device: commandBuffer.device
        ), encodeRenderPass(
            pipeline: pipeline,
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            targetTexture: targetTexture,
            includesParameters: true
        ) {
            return
        }

        logFailureOnce()
        encodeUnmodifiedSource(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            targetTexture: targetTexture
        )
    }

    func cachedPipeline(
        for pixelFormat: MTLPixelFormat,
        device: any MTLDevice
    ) -> MTLRenderPipelineState? {
        pipeline(for: pixelFormat, kind: .filmic, device: device)
    }

    private func pipeline(
        for pixelFormat: MTLPixelFormat,
        kind: PipelineKind,
        device: any MTLDevice
    ) -> MTLRenderPipelineState? {
        let key = PipelineKey(pixelFormat: pixelFormat, kind: kind)
        lock.lock()
        defer { lock.unlock() }

        if let pipeline = pipelines[key] {
            return pipeline
        }
        guard !failedPipelineKeys.contains(key) else { return nil }

        if library == nil, preparationError == nil {
            library = libraryLoader(device)
            if library == nil {
                preparationError = "Unable to load the UniverseModule Metal library"
            }
        }
        guard let library else { return nil }

        let fragmentName = switch kind {
        case .filmic: "universe_postfx_fragment"
        case .passthrough: "universe_postfx_passthrough_fragment"
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Universe \(kind) post-processing"
        descriptor.vertexFunction = library.makeFunction(name: "universe_postfx_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: fragmentName)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        do {
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            pipelines[key] = pipeline
            pipelineCreationCount += 1
            return pipeline
        } catch {
            failedPipelineKeys.insert(key)
            preparationError = String(describing: error)
            return nil
        }
    }

    private func encodeRenderPass(
        pipeline: any MTLRenderPipelineState,
        commandBuffer: any MTLCommandBuffer,
        sourceTexture: any MTLTexture,
        targetTexture: any MTLTexture,
        includesParameters: Bool
    ) -> Bool {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = targetTexture
        descriptor.colorAttachments[0].loadAction = .dontCare
        descriptor.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return false
        }

        encoder.label = includesParameters ? "Filmic PostFX" : "PostFX Passthrough"
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        if includesParameters {
            var parameters = PostFXParams.filmic
            encoder.setFragmentBytes(
                &parameters,
                length: MemoryLayout<PostFXParams>.stride,
                index: 0
            )
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    private func encodeUnmodifiedSource(
        commandBuffer: any MTLCommandBuffer,
        sourceTexture: any MTLTexture,
        targetTexture: any MTLTexture
    ) {
        if let pipeline = pipeline(
            for: targetTexture.pixelFormat,
            kind: .passthrough,
            device: commandBuffer.device
        ), encodeRenderPass(
            pipeline: pipeline,
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            targetTexture: targetTexture,
            includesParameters: false
        ) {
            return
        }

        guard sourceTexture.pixelFormat == targetTexture.pixelFormat,
              sourceTexture.width == targetTexture.width,
              sourceTexture.height == targetTexture.height,
              sourceTexture.depth == targetTexture.depth,
              sourceTexture.sampleCount == 1,
              targetTexture.sampleCount == 1,
              let encoder = commandBuffer.makeBlitCommandEncoder() else {
            return
        }
        encoder.label = "PostFX Fallback Copy"
        encoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: .init(x: 0, y: 0, z: 0),
            sourceSize: .init(
                width: sourceTexture.width,
                height: sourceTexture.height,
                depth: sourceTexture.depth
            ),
            to: targetTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: .init(x: 0, y: 0, z: 0)
        )
        encoder.endEncoding()
    }

    private func logFailureOnce() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasLoggedFailure else { return }
        hasLoggedFailure = true
        let detail = preparationError ?? "Unknown encoding failure"
        logger.error("Filmic post-processing unavailable; using unmodified color. \(detail, privacy: .public)")
    }
}
