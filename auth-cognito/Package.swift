// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "auth-cognito",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/adam-fowler/soto-cognito-authentication-kit", from: "5.0.0-alpha.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
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
