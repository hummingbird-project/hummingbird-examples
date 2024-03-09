// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "hummingbird-todos-lambda",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", branch: "main"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-lambda.git", branch: "main"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0-alpha"),
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
