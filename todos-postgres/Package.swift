// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "todos-postgres",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.16.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/fabianfett/postgres-nio", .branch("main"))
    ],
    targets: [
        .executableTarget(name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdFoundation", package: "hummingbird"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
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
