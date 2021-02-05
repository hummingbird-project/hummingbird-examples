// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "hummingbird-todos-lambda",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "HummingbirdTodosLambda", targets: ["Run"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime", from: "0.2.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.2.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "Run", dependencies: [
            .byName(name: "App")
        ]),
        .target(name: "App", dependencies: [
            .byName(name: "HummingbirdLambda"),
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "SotoDynamoDB", package: "soto")
        ]),
        .target(name: "HummingbirdLambda", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
            .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            .product(name: "Hummingbird", package: "hummingbird")
        ]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
