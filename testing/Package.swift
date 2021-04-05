// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "hummingbird-testing",
    products: [
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .upToNextMajor(from: "0.8.1")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "0.3.0")),
    ],
    targets: [
        .target(
            name: "hummingbird-testing",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
        ]),
        .target(name: "Run",
                dependencies: [
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
                    .target(name: "hummingbird-testing"),
                ]),
        .testTarget(
            name: "hummingbird-testingTests",
            dependencies: [
                "hummingbird-testing",
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ]),
    ]
)
