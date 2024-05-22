// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "auth-jwt",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-fluent", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/vapor/jwt-kit", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
        .package(url: "https://github.com/vapor/fluent-kit", from: "1.16.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HummingbirdAuthTesting", package: "hummingbird-auth"),
            ]
        ),
    ]
)
