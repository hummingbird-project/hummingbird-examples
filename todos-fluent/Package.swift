// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-todos-fluent",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "hummingbird-todos-fluent", targets: ["hummingbird-todos-fluent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.2.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-fluent.git", from: "0.1.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "hummingbird-todos-fluent", dependencies: [
            .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
    ]
)
