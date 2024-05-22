// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "multipart-form",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0-beta.5"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", .upToNextMinor(from: "0.7.0")),
        .package(url: "https://github.com/vapor/multipart-kit", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64"),
                .product(name: "MultipartKit", package: "multipart-kit"),
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
