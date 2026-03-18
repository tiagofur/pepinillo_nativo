// swift-tools-version: 6.0
// Package.swift
// Pepinillo — Deep Work Companion for Apple
//
// SPM package definition for shared code.
// The Xcode project will reference this for dependency management.
// Actual targets/schemes are configured in Xcode.
//
// NOTE: This file is for dependency declaration and local module structure.
// When creating the Xcode project on a Mac, add these packages via
// File → Add Package Dependencies using the URLs below.

import PackageDescription

let package = Package(
    name: "Pepinillo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "PepinilloCore",
            targets: ["PepinilloCore"]
        ),
    ],
    dependencies: [
        // TCA — The Composable Architecture (state management)
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.17.0"
        ),
        // Snapshot Testing (UI regression tests)
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.17.0"
        ),
    ],
    targets: [
        .target(
            name: "PepinilloCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: ".",
            exclude: ["Tests", "Package.swift"],
            sources: [
                "App",
                "Features",
                "Domain",
                "Shared",
            ]
        ),
        .testTarget(
            name: "PepinilloTests",
            dependencies: [
                "PepinilloCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests"
        ),
    ]
)
