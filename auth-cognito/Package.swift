// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "auth-cognito",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/adam-fowler/soto-cognito-authentication-kit.git", from: "5.0.0-alpha.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdRouter", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "SotoCognitoAuthenticationKit", package: "soto-cognito-authentication-kit"),
                .product(name: "SotoCognitoAuthenticationSRP", package: "soto-cognito-authentication-kit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
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
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        ),
    ]
)
