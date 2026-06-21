import Metal
import Testing
@testable import UniverseModule

@Test func postFXParametersMatchMetalBufferLayout() {
    #expect(MemoryLayout<PostFXParams>.size == 36)
    #expect(MemoryLayout<PostFXParams>.stride == 36)
    #expect(MemoryLayout<PostFXParams>.alignment == 4)
}

@Test func filmicPostProcessPipelineLoadsAndCachesByPixelFormat() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let renderer = FilmicPostProcessRenderer()
    renderer.prepare(for: device)

    let first = try #require(renderer.cachedPipeline(for: .rgba8Unorm, device: device))
    let second = try #require(renderer.cachedPipeline(for: .rgba8Unorm, device: device))
    let otherFormat = try #require(
        renderer.cachedPipeline(for: .rgba16Float, device: device)
    )

    #expect(first === second)
    #expect(first !== otherFormat)
    #expect(renderer.pipelineCreationCount == 2)
}

@Test func filmicPostProcessEncodesRealityKitSourceIntoTarget() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let commandQueue = try #require(device.makeCommandQueue())
    let source = try makeTexture(device: device, pixelFormat: .rgba8Unorm)
    let target = try makeTexture(device: device, pixelFormat: .rgba8Unorm)
    writeSolidRed(to: source)
    let commandBuffer = try #require(commandQueue.makeCommandBuffer())
    let renderer = FilmicPostProcessRenderer()
    renderer.prepare(for: device)

    renderer.encode(
        commandBuffer: commandBuffer,
        sourceTexture: source,
        targetTexture: target
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    #expect(commandBuffer.status == .completed)
    #expect(readFirstPixel(from: target)[0] > 0)
}

@Test func failedPostProcessPreparationCopiesUnmodifiedSource() throws {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let commandQueue = try #require(device.makeCommandQueue())
    let source = try makeTexture(device: device, pixelFormat: .rgba8Unorm)
    let target = try makeTexture(device: device, pixelFormat: .rgba8Unorm)
    let expected: [UInt8] = [17, 83, 149, 255]
    source.replace(
        region: MTLRegionMake2D(0, 0, 1, 1),
        mipmapLevel: 0,
        withBytes: expected,
        bytesPerRow: expected.count
    )
    let commandBuffer = try #require(commandQueue.makeCommandBuffer())
    let renderer = FilmicPostProcessRenderer(libraryLoader: { _ in nil })
    renderer.prepare(for: device)

    renderer.encode(
        commandBuffer: commandBuffer,
        sourceTexture: source,
        targetTexture: target
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    #expect(commandBuffer.status == .completed)
    #expect(readFirstPixel(from: target) == expected)
}

private func makeTexture(
    device: any MTLDevice,
    pixelFormat: MTLPixelFormat
) throws -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: pixelFormat,
        width: 1,
        height: 1,
        mipmapped: false
    )
    descriptor.storageMode = .shared
    descriptor.usage = [.shaderRead, .renderTarget]
    return try #require(device.makeTexture(descriptor: descriptor))
}

private func writeSolidRed(to texture: any MTLTexture) {
    var pixel: [UInt8] = [255, 0, 0, 255]
    texture.replace(
        region: MTLRegionMake2D(0, 0, 1, 1),
        mipmapLevel: 0,
        withBytes: &pixel,
        bytesPerRow: pixel.count
    )
}

private func readFirstPixel(from texture: any MTLTexture) -> [UInt8] {
    var pixel = [UInt8](repeating: 0, count: 4)
    texture.getBytes(
        &pixel,
        bytesPerRow: pixel.count,
        from: MTLRegionMake2D(0, 0, 1, 1),
        mipmapLevel: 0
    )
    return pixel
}
