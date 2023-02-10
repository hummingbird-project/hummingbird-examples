// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "hummingbird-todos-lambda",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "HummingbirdTodosLambda", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-lambda.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(name: "App", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "HummingbirdLambda", package: "hummingbird-lambda"),
            .product(name: "SotoDynamoDB", package: "soto"),
        ]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
    ]
)
