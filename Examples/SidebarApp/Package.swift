// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SidebarApp",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "SidebarApp",
            dependencies: [.product(name: "ViewComponent", package: "view_component_swift")],
            exclude: [
                "Components/sidebar_component/sidebar_component.css",
                "Components/sidebar_component/sidebar_component.js",
            ],
            plugins: [.plugin(name: "ViewComponentTemplates", package: "view_component_swift")]
        )
    ]
)
