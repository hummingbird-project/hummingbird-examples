// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "todos-lambda",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-rc.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-lambda.git", from: "2.0.0-beta.6"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0-rc.1"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdLambda", package: "hummingbird-lambda"),
                .product(name: "SotoDynamoDB", package: "soto"),
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
            dependencies: ["App"]
        ),
    ]
)
