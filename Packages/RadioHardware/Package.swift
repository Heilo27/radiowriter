// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RadioHardware",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadioHardware", targets: ["USBTransport", "RadioProgrammer", "Discovery"]),
        .executable(name: "XPRTest", targets: ["XPRTest"]),
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
        .executableTarget(
            name: "XPRTest",
            dependencies: ["RadioProgrammer"],
            path: "Sources/XPRTest",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(
            name: "RadioHardwareTests",
            dependencies: ["USBTransport", "RadioProgrammer", "Discovery"],
            path: "Tests/RadioHardwareTests"
        ),
    ]
)
