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
        .package(path: "./../hpple"),
        .package(path: "./../SQLite.swift"),
    ],
    targets: [
        .target(
            name: "BookmarksCore",
            dependencies: [
                .product(name: "Diligence", package: "Diligence"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "TFHpple", package: "hpple"),
            ],
            resources: [
                .process("Licenses"),
            ]),
        .testTarget(
            name: "BookmarksCoreTests",
            dependencies: ["BookmarksCore"]),
    ]
)
