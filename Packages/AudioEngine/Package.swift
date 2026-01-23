// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AudioEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
    ],
    dependencies: [
        .package(path: "../RadioCore"),
    ],
    targets: [
        .target(
            name: "AudioEngine",
            dependencies: ["RadioCore"],
            path: "Sources/AudioEngine"
        ),
        .testTarget(
            name: "AudioEngineTests",
            dependencies: ["AudioEngine"],
            path: "Tests/AudioEngineTests"
        ),
    ]
)
