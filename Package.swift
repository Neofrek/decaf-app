// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Decaf",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Decaf", targets: ["Decaf"])
    ],
    targets: [
        .executableTarget(name: "Decaf")
    ]
)
