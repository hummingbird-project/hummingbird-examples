// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "webauthn",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/webauthn-swift.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "WebAuthn", package: "webauthn-swift"),
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
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ]
        ),
    ]
)
