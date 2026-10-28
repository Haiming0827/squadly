import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreparedPhoto {
  let bytes: Data
  let width: Int
  let height: Int
}

enum PhotoPreparationError: Error {
  case invalidImage
  case imageTooLarge
}

enum PhotoSanitizer {
  static let maxInputBytes = 40 * 1024 * 1024
  static let maxBytes = 2 * 1024 * 1024
  static let maxDimension = 1600

  static func prepare(_ data: Data) throws -> PreparedPhoto {
    guard data.count <= maxInputBytes else { throw PhotoPreparationError.imageTooLarge }
    guard !data.isEmpty,
      let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) == 1,
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        kCGImageSourceShouldCacheImmediately: true,
      ] as CFDictionary), image.width > 0, image.height > 0,
      image.width <= maxDimension, image.height <= maxDimension,
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let pixels = CGContext(
        data: nil, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    else { throw PhotoPreparationError.invalidImage }

    // Never forward source properties. Redraw into a new sRGB pixel buffer.
    pixels.setFillColor(CGColor(gray: 1, alpha: 1))
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    pixels.fill(rect)
    pixels.draw(image, in: rect)
    guard let clean = pixels.makeImage() else { throw PhotoPreparationError.invalidImage }
    for quality in [0.85, 0.7, 0.55, 0.4] {
      let bytes = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)
      else { throw PhotoPreparationError.invalidImage }
      CGImageDestinationAddImage(destination, clean, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
      guard CGImageDestinationFinalize(destination) else { throw PhotoPreparationError.invalidImage }
      let prepared = try removeAuxiliarySegments(bytes as Data)
      if prepared.count <= maxBytes {
        return PreparedPhoto(bytes: prepared, width: clean.width, height: clean.height)
      }
    }
    throw PhotoPreparationError.imageTooLarge
  }

  // Image I/O can synthesize fresh EXIF/IPTC even without copied properties.
  // Remove auxiliary header segments only AFTER decoding/redrawing/re-encoding;
  // doing this to the source alone would not be a sufficient privacy boundary.
  private static func removeAuxiliarySegments(_ encoded: Data) throws -> Data {
    let bytes = [UInt8](encoded)
    guard bytes.count > 10, bytes[0] == 0xff, bytes[1] == 0xd8,
      bytes[bytes.count - 2] == 0xff, bytes[bytes.count - 1] == 0xd9
    else { throw PhotoPreparationError.invalidImage }
    var output = Data([0xff, 0xd8])
    var offset = 2
    while offset + 3 < bytes.count {
      let start = offset
      guard bytes[offset] == 0xff else { throw PhotoPreparationError.invalidImage }
      let marker = bytes[offset + 1]
      if marker == 0xda {
        output.append(contentsOf: bytes[start...])
        return output
      }
      guard marker != 0xd8, marker != 0xd9, marker != 0x00, marker != 0xff
      else { throw PhotoPreparationError.invalidImage }
      let length = Int(bytes[offset + 2]) * 256 + Int(bytes[offset + 3])
      guard length >= 2, offset + 2 + length <= bytes.count - 2
      else { throw PhotoPreparationError.invalidImage }
      offset += 2 + length
      if marker != 0xe1 && !(0xe3...0xef).contains(marker) && marker != 0xfe {
        output.append(contentsOf: bytes[start..<offset])
      }
    }
    throw PhotoPreparationError.invalidImage
  }
}
