// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "jobs",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-valkey.git", from: "0.1.0"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-jobs-valkey.git", from: "1.0.0-rc.2"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdValkey", package: "hummingbird-valkey"),
                .product(name: "Jobs", package: "swift-jobs"),
                .product(name: "JobsValkey", package: "swift-jobs-valkey"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
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
