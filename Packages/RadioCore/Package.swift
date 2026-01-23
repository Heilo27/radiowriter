// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RadioCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadioCore", targets: ["RadioCore"]),
    ],
    targets: [
        .target(
            name: "RadioCore",
            path: "Sources/RadioCore"
        ),
        .testTarget(
            name: "RadioCoreTests",
            dependencies: ["RadioCore"],
            path: "Tests/RadioCoreTests"
        ),
    ]
)
