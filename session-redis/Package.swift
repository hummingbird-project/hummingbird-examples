// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-session-redis",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "hummingbird-session-redis", targets: ["hummingbird-session-redis"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .branch("main")),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", .branch("main")),
        .package(url: "https://github.com/hummingbird-project/hummingbird-fluent.git", from: "0.1.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-redis.git", from: "0.1.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "hummingbird-session-redis",
            dependencies: [
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
                .product(name: "HummingbirdFoundation", package: "hummingbird"),
                .product(name: "HummingbirdRedis", package: "hummingbird-redis"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
    ]
)
