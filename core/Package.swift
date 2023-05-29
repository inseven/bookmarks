// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "BookmarksCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BookmarksCore",
            targets: ["BookmarksCore"]),
    ],
    dependencies: [
        .package(path: "./../diligence"),
        .package(path: "./../interact"),
        .package(path: "./../hpple"),
        .package(path: "./../SQLite.swift"),
        .package(url: "https://github.com/ksemianov/WrappingHStack.git", branch: "main"),
        .package(url: "https://github.com/saramah/HashRainbow.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "BookmarksCore",
            dependencies: [
                .product(name: "Diligence", package: "Diligence"),
                .product(name: "Interact", package: "Interact"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "TFHpple", package: "hpple"),
                .product(name: "WrappingHStack", package: "WrappingHStack"),
                .product(name: "HashRainbow", package: "HashRainbow"),
            ],
            resources: [
                .process("Licenses"),
            ]),
        .testTarget(
            name: "BookmarksCoreTests",
            dependencies: ["BookmarksCore"]),
    ]
)
