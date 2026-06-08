import Foundation
import ImageIO
import Testing
@testable import MetalModule

@Test func milkyWayEnvironmentAssetIsBundledAndEquirectangular() throws {
    let url = try #require(MetalModuleAssets.milkyWayEnvironmentURL())
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    let fileSize = try #require(values.fileSize)

    #expect(fileSize > 0)

    let imageSource = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
    )
    let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
    let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
    let aspectRatio = Double(width) / Double(height)

    #expect(width >= 4_000)
    #expect(height >= 2_000)
    #expect(abs(aspectRatio - 2.0) < 0.02)
}
