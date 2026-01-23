// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RadioHardware",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadioHardware", targets: ["USBTransport", "RadioProgrammer", "Discovery"]),
    ],
    dependencies: [
        .package(path: "../RadioCore"),
        .package(path: "../RadioModels"),
    ],
    targets: [
        .target(
            name: "USBTransport",
            dependencies: ["RadioCore"],
            path: "Sources/USBTransport"
        ),
        .target(
            name: "RadioProgrammer",
            dependencies: ["RadioCore", "USBTransport",
                           .product(name: "RadioModelCore", package: "RadioModels")],
            path: "Sources/RadioProgrammer"
        ),
        .target(
            name: "Discovery",
            dependencies: ["USBTransport"],
            path: "Sources/Discovery"
        ),
        .testTarget(
            name: "RadioHardwareTests",
            dependencies: ["USBTransport", "RadioProgrammer", "Discovery"],
            path: "Tests/RadioHardwareTests"
        ),
    ]
)
