// swift-tools-version: 6.0
// Everyday Contract — shared protocol contracts only.
//
// This package contains versioned messages, synchronization projections, compatibility rules,
// schema validation, and contract-level security expectations. It contains no Host services,
// persistence, execution, orchestration, application adapters, presentation, or state management.

import PackageDescription

let package = Package(
    name: "EverydayContract",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "EverydayContract", targets: ["EverydayContract"])
    ],
    // This package has no dependencies. In particular, it must never depend on either application.
    dependencies: [],
    targets: [
        .target(
            name: "EverydayContract"
        ),
        .testTarget(
            name: "EverydayContractTests",
            dependencies: ["EverydayContract"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
