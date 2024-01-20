// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Todos",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", branch: "2.x.x"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.20.0"),
    ],
    targets: [
        .executableTarget(
            name: "Todos",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "_ConnectionPoolModule", package: "postgres-nio"),
            ]
        ),
        .testTarget(
            name: "TodosTests",
            dependencies: [
                "Todos",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ]
        ),
    ]
)
