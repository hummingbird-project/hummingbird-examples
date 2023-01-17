// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "auth-jwt",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "Server", targets: ["Server"]),
  ],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "1.0.0-rc"),
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "1.0.0-rc"),
    .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "HummingbirdFoundation", package: "hummingbird"),
        .product(name: "JWTKit", package: "jwt-kit"),
      ],
      swiftSettings: [
        // Enable better optimizations when building in Release configuration. Despite the use of
        // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
        // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
        .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
      ]
    ),
    .executableTarget(
      name: "Server",
      dependencies: [
        .target(name: "App"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "AppTests",
      dependencies: [
        .byName(name: "App"),
        .product(name: "HummingbirdXCT", package: "hummingbird"),
      ]
    ),
  ]
)
