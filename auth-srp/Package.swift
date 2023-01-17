// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "auth-srp",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "Server", targets: ["Server"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-fluent.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.0"),
        .package(url: "https://github.com/adam-fowler/swift-srp.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                .byName(name: "App"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
                .product(name: "HummingbirdFoundation", package: "hummingbird"),
                .product(name: "SRP", package: "swift-srp"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "HummingbirdXCT", package: "hummingbird"),
                .product(name: "SRP", package: "swift-srp"),
            ]
        ),
    ]
)
