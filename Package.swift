// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "Aanbiedingspan",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "App", targets: ["App"]),
    .executable(name: "Run", targets: ["Run"]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", exact: "4.122.0"),
    .package(url: "https://github.com/vapor/leaf.git", exact: "4.5.2"),
    .package(url: "https://github.com/vapor/fluent.git", exact: "4.13.0"),
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", exact: "2.12.0"),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Leaf", package: "leaf"),
        .product(name: "Fluent", package: "fluent"),
        .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
      ]
    ),
    .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    .testTarget(
      name: "AppTests",
      dependencies: [
        .target(name: "App"),
        .product(name: "XCTVapor", package: "vapor"),
      ]
    ),
  ]
)
