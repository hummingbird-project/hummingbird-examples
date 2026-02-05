// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "jobs-example",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.19.0"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs.git", from: "1.1.0"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs-valkey.git", from: "1.0.0-rc.4"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Jobs", package: "swift-jobs"),
                .product(name: "JobsValkey", package: "swift-jobs-valkey"),
            ],
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        ),
    ]
)
