// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "BookmarksCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "BookmarksCore",
            targets: ["BookmarksCore"])
    ],
    dependencies: [
        .package(path: "./../dependencies/diligence"),
        .package(path: "./../dependencies/interact"),
        .package(path: "./../dependencies/hpple"),
        .package(path: "./../dependencies/SQLite.swift"),
        .package(path: "./../dependencies/SelectableCollectionView"),
        .package(url: "https://github.com/ksemianov/WrappingHStack.git", branch: "main"),
        .package(url: "https://github.com/saramah/HashRainbow.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "BookmarksCore",
            dependencies: [
                .product(name: "Diligence", package: "Diligence"),
                .product(name: "Interact", package: "Interact"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "TFHpple", package: "hpple"),
                "WrappingHStack",
                "HashRainbow",
                "SwiftSoup",
                .product(name: "SelectableCollectionView", package: "SelectableCollectionView"),
            ],
            resources: [
                .process("Licenses"),
                .process("Resources"),
            ]),
        .testTarget(
            name: "BookmarksCoreTests",
            dependencies: ["BookmarksCore"]),
    ]
)
