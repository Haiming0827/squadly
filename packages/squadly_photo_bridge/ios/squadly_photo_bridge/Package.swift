// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "squadly_photo_bridge",
  platforms: [.iOS("15.0"), .macOS("12.0")],
  products: [.library(name: "squadly-photo-bridge", targets: ["squadly_photo_bridge"])],
  targets: [
    .target(name: "squadly_photo_bridge"),
    .testTarget(name: "PhotoSanitizerTests", dependencies: ["squadly_photo_bridge"]),
  ]
)
