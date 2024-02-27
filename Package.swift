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
    ], 
    targets: [
        .target(name: "LocoKit2", dependencies: ["Surge"]),
        .testTarget(name: "LocoKit2Tests", dependencies: ["LocoKit2"])
    ]
)
