// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird-html-form",
    products: [
        .executable(name: "hummingbird-html-form", targets: ["hummingbird-html-form"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.8.0")
    ],
    targets: [
        .target(name: "hummingbird-html-form", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "Plot", package: "Plot"),
        ]),
    ]
)
