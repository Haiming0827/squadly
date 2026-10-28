import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import squadly_photo_bridge

final class PhotoSanitizerTests: XCTestCase {
  private func fixture(width: Int = 3000, height: Int = 1000, orientation: Int = 6) throws -> Data {
    let context = try XCTUnwrap(CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), [
      kCGImagePropertyOrientation: orientation,
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 31.23, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 121.47, kCGImagePropertyGPSLongitudeRef: "E",
      ],
      kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:27 10:11:12"],
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Private camera name"],
    ] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  func testRemovesLocationAndSourceMetadataAndNormalizesOrientation() throws {
    let input = try fixture()
    let original = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
    let originalProperties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(original, 0, nil) as? [String: Any])
    XCTAssertNotNil(originalProperties[kCGImagePropertyGPSDictionary as String])
    XCTAssertNotNil(originalProperties[kCGImagePropertyExifDictionary as String])

    let output = try PhotoSanitizer.prepare(input)
    XCTAssertEqual(max(output.width, output.height), 1600)
    XCTAssertLessThan(output.width, output.height)
    XCTAssertLessThanOrEqual(output.bytes.count, PhotoSanitizer.maxBytes)
    let source = try XCTUnwrap(CGImageSourceCreateWithData(output.bytes as CFData, nil))
    XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
    let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
    XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal as String])
    let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
    XCTAssertNil(tiff?[kCGImagePropertyTIFFMake as String])
    let orientation = properties[kCGImagePropertyOrientation as String] as? Int
    XCTAssertTrue(orientation == nil || orientation == 1)
    XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source, 0, nil))
  }

  func testSmallImageKeepsDimensions() throws {
    let output = try PhotoSanitizer.prepare(fixture(width: 320, height: 240, orientation: 1))
    XCTAssertEqual(output.width, 320)
    XCTAssertEqual(output.height, 240)
  }

  func testPreparedHeaderMatchesDartMetadataRejectionContract() throws {
    let output = try PhotoSanitizer.prepare(fixture(width: 320, height: 240, orientation: 1))
    let bytes = [UInt8](output.bytes)
    var offset = 2
    var foundScan = false
    while offset + 3 < bytes.count {
      XCTAssertEqual(bytes[offset], 0xff)
      let marker = bytes[offset + 1]
      if marker == 0xda { foundScan = true; break }
      // Dart rejects APP1/APP3-15 and comments to avoid source metadata.
      XCTAssertFalse(marker == 0xe1 || (0xe3...0xef).contains(marker) || marker == 0xfe)
      let length = Int(bytes[offset + 2]) * 256 + Int(bytes[offset + 3])
      XCTAssertGreaterThanOrEqual(length, 2)
      offset += 2 + length
    }
    XCTAssertTrue(foundScan)
  }

  func testInvalidOrOversizedInputIsRejected() {
    for input in [Data(), Data("not an image".utf8), Data([0xff, 0xd8, 0xff, 0xd9])] {
      XCTAssertThrowsError(try PhotoSanitizer.prepare(input))
    }
    XCTAssertThrowsError(try PhotoSanitizer.prepare(Data(count: PhotoSanitizer.maxInputBytes + 1))) {
      XCTAssertEqual($0 as? PhotoPreparationError, .imageTooLarge)
    }
  }

  func testDoesNotReturnOriginalCompressedSource() throws {
    let input = try fixture(width: 200, height: 100, orientation: 1)
    let output = try PhotoSanitizer.prepare(input)
    XCTAssertNotEqual(input, output.bytes)
    XCTAssertFalse(String(decoding: output.bytes, as: UTF8.self).contains("Private camera name"))
    XCTAssertFalse(String(decoding: output.bytes, as: UTF8.self).contains("2026:10:27"))
  }
}
