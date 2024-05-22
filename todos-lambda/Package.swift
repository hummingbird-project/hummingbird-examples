// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "todos-lambda",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-lambda", from: "2.0.0-beta.3"),
        .package(url: "https://github.com/soto-project/soto", from: "7.0.0-rc.1"),
    ],
    targets: [
        .executableTarget(name: "App", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdLambda", package: "hummingbird-lambda"),
            .product(name: "SotoDynamoDB", package: "soto"),
        ]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
    ]
)
