// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VietKey",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Engine", targets: ["Engine"]),
        .library(name: "EventTap", targets: ["EventTap"]),
        .executable(name: "VietKey", targets: ["App"]),
    ],
    targets: [
        .target(
            name: "Engine",
            path: "Sources/Engine"
        ),
        .target(
            name: "EventTap",
            dependencies: ["Engine"],
            path: "Sources/EventTap"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Engine", "EventTap"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "EngineTests",
            dependencies: ["Engine"],
            path: "Tests/EngineTests"
        ),
    ]
)
