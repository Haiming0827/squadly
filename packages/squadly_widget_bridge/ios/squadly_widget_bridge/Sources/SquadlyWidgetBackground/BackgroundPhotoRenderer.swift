import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SquadlyWidgetCore

public enum BackgroundPhotoRenderer {
  /// Decode only a single bounded frame, then encode new opaque sRGB pixels.
  /// No source dictionaries, EXIF or location are copied to the destination.
  public static func thumbnail(_ bytes: Data, width: Int, height: Int) throws -> Data {
    guard !bytes.isEmpty, bytes.count <= 2 * 1024 * 1024,
      let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) == 1,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      properties[kCGImagePropertyPixelWidth] as? Int == width, properties[kCGImagePropertyPixelHeight] as? Int == height,
      (1...1600).contains(width), (1...1600).contains(height),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 640] as CFDictionary),
      let color = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: color, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw BackgroundSyncError.invalid }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect); context.draw(image, in: rect)
    guard let clean = context.makeImage() else { throw BackgroundSyncError.invalid }
    for quality in [0.8, 0.65, 0.5] {
      let result = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else { throw BackgroundSyncError.invalid }
      CGImageDestinationAddImage(destination, clean, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
      guard CGImageDestinationFinalize(destination) else { throw BackgroundSyncError.invalid }
      if result.length <= WidgetManifest.maximumJPEGBytes { return result as Data }
    }
    throw BackgroundSyncError.invalid
  }
}
