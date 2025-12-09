// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocoKit2",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "LocoKit2", targets: ["LocoKit2"])
    ],
    dependencies: [
        .package(url: "https://github.com/Jounce/Surge", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
        .package(url: "https://github.com/Adorkable/swift-log-format-and-pipe", from: "0.1.1"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.1.0")
    ],
    targets: [
        .target(name: "LocoKit2", dependencies: [
            "Surge",
            .product(name: "GRDB", package: "GRDB.swift"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "LoggingFormatAndPipe", package: "swift-log-format-and-pipe")
        ]),
        .testTarget(name: "LocoKit2Tests", dependencies: ["LocoKit2"])
    ]
)
