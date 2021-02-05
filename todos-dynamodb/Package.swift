// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-todos-dynamodb",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "hummingbird-todos-dynamodb", targets: ["hummingbird-todos-dynamodb"]),
    ], 
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .branch("main")),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "hummingbird-todos-dynamodb", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SotoDynamoDB", package: "soto")
        ]),
    ]
)
