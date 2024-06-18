// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "todos-mongokitten-openapi",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-beta.8"),
        .package(url: "https://github.com/swift-server/swift-openapi-hummingbird.git", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.3.0"),
        .package(url: "https://github.com/orlandos-nl/mongokitten.git", from: "7.0.0"),
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
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .testTarget(
            name: "TodosOpenAPITests",
            dependencies: []
        ),
    ]
)
