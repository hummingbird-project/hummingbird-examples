// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "todos-auth-fluent",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-fluent", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
                .product(name: "Mustache", package: "swift-mustache"),
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
