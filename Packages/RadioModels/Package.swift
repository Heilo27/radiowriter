// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RadioModels",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadioModels", targets: [
            "RadioModelCore", "APX", "CLP", "CLP2", "CP200", "DLRx", "Dtr", "Fiji", "Nome", "RDM", "Renoir", "RMM", "Solo", "Sunb", "Vanu", "XPR",
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
            name: "APX",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/APX"
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
            name: "CP200",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/CP200"
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
            name: "RDM",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/RDM"
        ),
        .target(
            name: "Renoir",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/Renoir"
        ),
        .target(
            name: "RMM",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/RMM"
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
        .target(
            name: "XPR",
            dependencies: ["RadioModelCore", "RadioCore"],
            path: "Sources/XPR"
        ),
        .testTarget(
            name: "RadioModelsTests",
            dependencies: ["RadioModelCore", "APX", "CLP", "CLP2", "CP200", "DLRx", "Dtr", "Fiji", "Nome", "RDM", "Renoir", "RMM", "Solo", "Sunb", "Vanu", "XPR"],
            path: "Tests/RadioModelsTests"
        ),
    ]
)
