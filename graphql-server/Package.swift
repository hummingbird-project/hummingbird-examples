// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "graphql-server",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "Server", targets: ["Server"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.11.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/GraphQLSwift/Graphiti.git", .upToNextMinor(from: "0.23.0")),
        .package(url: "https://github.com/rexmas/JSONValue.git", .upToNextMajor(from: "7.0.0")),
    ],
    targets: [
        .target(name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdFoundation", package: "hummingbird"),
                .product(name: "Graphiti", package: "Graphiti"),
                .product(name: "JSONValueRX", package: "JSONValue"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "Server",
            dependencies: [
                .byName(name: "App"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdXCT", package: "hummingbird")
            ]
        )
    ]
)
