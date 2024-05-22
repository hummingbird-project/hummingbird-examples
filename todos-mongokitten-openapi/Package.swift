// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "todos-mongokitten-openapi",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", branch: "2.0.0-beta.5"),
        .package(url: "https://github.com/swift-server/swift-openapi-hummingbird", branch: "2.0.0-beta.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.3.0"),
        .package(url: "https://github.com/orlandos-nl/mongokitten", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "TodosOpenAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .executableTarget(
            name: "todos-mongokitten-openapi",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "MongoKitten", package: "mongokitten"),
                .product(name: "OpenAPIHummingbird", package: "swift-openapi-hummingbird"),
                .target(name: "TodosOpenAPI"),
            ]
        ),
    ]
)
