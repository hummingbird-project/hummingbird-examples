// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "auth-cognito",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "auth-cognito", targets: ["auth-cognito"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "0.1.0"),
        .package(url: "https://github.com/adam-fowler/soto-cognito-authentication-kit.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "auth-cognito",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdFoundation", package: "hummingbird"),
                .product(name: "SotoCognitoAuthenticationKit", package: "soto-cognito-authentication-kit"),
                .product(name: "SotoCognitoAuthenticationSRP", package: "soto-cognito-authentication-kit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
    ]
)
