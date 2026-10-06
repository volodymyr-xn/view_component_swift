// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "view_component_swift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ViewComponent", targets: ["ViewComponent"]),
        .library(name: "ViewComponentTesting", targets: ["ViewComponentTesting"]),
        .plugin(name: "ViewComponentTemplates", targets: ["ViewComponentTemplates"]),
    ],
    targets: [
        .target(name: "ViewComponentTemplateSyntax"),
        .target(name: "ViewComponent", dependencies: ["ViewComponentTemplateSyntax"]),
        .target(name: "ViewComponentTesting", dependencies: ["ViewComponent"]),
        .executableTarget(
            name: "ViewComponentTemplateCompiler",
            dependencies: ["ViewComponentTemplateSyntax"]
        ),
        .plugin(
            name: "ViewComponentTemplates",
            capability: .buildTool(),
            dependencies: ["ViewComponentTemplateCompiler"]
        ),
        .testTarget(
            name: "ViewComponentSyntaxTests",
            dependencies: ["ViewComponentTemplateSyntax"]
        ),
        .testTarget(
            name: "ViewComponentTests",
            dependencies: ["ViewComponent", "ViewComponentTesting"],
            resources: [.copy("Components/sidebar_group_component/sidebar_group_component.css")],
            plugins: ["ViewComponentTemplates"]
        ),
    ]
)
