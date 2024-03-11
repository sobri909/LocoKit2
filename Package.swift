// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        .package(name: "Logging", url: "https://github.com/apple/swift-log", from: "1.5.4"),
        .package(name: "LoggingFormatAndPipe", url: "https://github.com/Adorkable/swift-log-format-and-pipe", from: "0.1.1"),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", from: "6.25.0"),
    ],
    targets: [
        .target(name: "LocoKit2", dependencies: ["Surge", "GRDB", "Logging", "LoggingFormatAndPipe"]),
        .testTarget(name: "LocoKit2Tests", dependencies: ["LocoKit2"])
    ]
)
