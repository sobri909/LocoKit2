// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocoKit2",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "LocoKit2", targets: ["LocoKit2"])
    ],
    dependencies: [
        .package(url: "https://github.com/Jounce/Surge", from: "2.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.1.0")
    ],
    targets: [
        .target(
            name: "LocoKit2",
            dependencies: [
                "Surge",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(name: "LocoKit2Tests", dependencies: ["LocoKit2"])
    ]
)
