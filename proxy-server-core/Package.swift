// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "proxy-server-core",
    platforms: [.macOS(.v10_14)],
    products: [
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird-core.git", .upToNextMinor(from: "0.13.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.6.0"),
    ],
    targets: [
        .executableTarget(name: "App",
            dependencies: [
                .product(name: "HummingbirdCore", package: "hummingbird-core"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
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
                .product(name: "HummingbirdCoreXCT", package: "hummingbird-core")
            ]
        )
    ]
)
