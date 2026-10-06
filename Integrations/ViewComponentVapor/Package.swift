// swift-tools-version: 6.1

import PackageDescription

/// Kept out of the core package on purpose: a library that everyone imports
/// should not drag Vapor and its dependency graph into every consumer's
/// resolution. Point at it with `.package(path:)` in a monorepo, or vendor the
/// three files it holds.
let package = Package(
    name: "view_component_vapor",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ViewComponentVapor", targets: ["ViewComponentVapor"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    ],
    targets: [
        .target(
            name: "ViewComponentVapor",
            dependencies: [
                .product(name: "ViewComponent", package: "view_component_swift"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "ViewComponentVaporTests",
            dependencies: [
                "ViewComponentVapor",
                .product(name: "VaporTesting", package: "vapor"),
            ],
            plugins: [.plugin(name: "ViewComponentTemplates", package: "view_component_swift")]
        ),
    ]
)
