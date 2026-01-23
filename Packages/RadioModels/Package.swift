// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RadioModels",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadioModels", targets: [
            "RadioModelCore", "CLP", "CLP2", "DLRx", "Dtr", "Fiji", "Nome", "Renoir", "Solo", "Sunb", "Vanu",
        ]),
        .library(name: "RadioModelCore", targets: ["RadioModelCore"]),
    ],
    dependencies: [
        .package(path: "../RadioCore"),
    ],
    targets: [
        .target(
            name: "RadioModelCore",
            dependencies: ["RadioCore"],
            path: "Sources/RadioModelCore"
        ),
        .target(
            name: "CLP",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/CLP"
        ),
        .target(
            name: "CLP2",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/CLP2"
        ),
        .target(
            name: "DLRx",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/DLRx"
        ),
        .target(
            name: "Dtr",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Dtr"
        ),
        .target(
            name: "Fiji",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Fiji"
        ),
        .target(
            name: "Nome",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Nome"
        ),
        .target(
            name: "Renoir",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Renoir"
        ),
        .target(
            name: "Solo",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Solo"
        ),
        .target(
            name: "Sunb",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Sunb"
        ),
        .target(
            name: "Vanu",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Vanu"
        ),
        .testTarget(
            name: "RadioModelsTests",
            dependencies: ["RadioModelCore", "CLP", "CLP2", "DLRx", "Dtr", "Fiji", "Nome", "Renoir", "Solo", "Sunb", "Vanu"],
            path: "Tests/RadioModelsTests"
        ),
    ]
)
