// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-http2",
    products: [
        .executable(name: "hummingbird-http2", targets: ["hummingbird-http2"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "hummingbird-http2", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdHTTP2", package: "hummingbird"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
    ]
)
