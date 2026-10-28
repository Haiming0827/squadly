// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "squadly_widget_bridge",
  platforms: [.iOS("15.0"), .macOS("12.0")],
  products: [
    .library(name: "squadly-widget-bridge", targets: ["squadly_widget_bridge"]),
    .library(name: "SquadlyWidgetCore", targets: ["SquadlyWidgetCore"]),
  ],
  targets: [
    .target(name: "SquadlyWidgetCore"),
    .target(name: "SquadlyWidgetBackground", dependencies: ["SquadlyWidgetCore"]),
    .target(name: "squadly_widget_bridge", dependencies: ["SquadlyWidgetCore", "SquadlyWidgetBackground"]),
    .testTarget(name: "SquadlyWidgetCoreTests", dependencies: ["SquadlyWidgetCore"]),
    .testTarget(name: "SquadlyWidgetBackgroundTests", dependencies: ["SquadlyWidgetBackground", "SquadlyWidgetCore"]),
  ]
)
