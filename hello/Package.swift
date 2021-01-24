// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-hello",
    products: [
        .executable(name: "hummingbird-hello", targets: ["hummingbird-hello"]),
    ],
    dependencies: [
        .package(url: "https://github.com/adam-fowler/hummingbird.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "hummingbird-hello", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
    ]
)
