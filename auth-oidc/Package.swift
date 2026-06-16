// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "auth-oidc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
        // Local path while HummingbirdOIDC is not yet in a tagged release.
        // Change to: .package(url: "https://github.com/iainsmith/hummingbird-auth.git", from: "<next-version>")
        .package(path: "../../hummingbird-auth"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdOIDC", package: "hummingbird-auth"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HummingbirdAuthTesting", package: "hummingbird-auth"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
    ]
)
