// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "auth-cognito",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.2.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", branch: "main"),
        .package(url: "https://github.com/adam-fowler/soto-cognito-authentication-kit.git", from: "5.0.0-rc.4"),
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
