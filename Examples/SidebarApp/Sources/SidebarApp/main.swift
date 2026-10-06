import ViewComponent

func buildSidebar(currentPath: String) -> SidebarComponent {
    let workspace = SidebarSectionComponent(
        title: "Workspace",
        links: [
            SidebarLinkComponent(label: "Overview", href: "/", icon: "◱"),
            SidebarLinkComponent(label: "Projects", href: "/projects", icon: "▤")
                .withBadgeCount(3),
            SidebarLinkComponent(label: "Q&A <beta>", href: "/qa", icon: "?"),
        ])

    let reports = SidebarSectionComponent(
        title: "Reports",
        links: [
            SidebarLinkComponent(label: "Revenue", href: "/reports/revenue", icon: "€"),
            SidebarLinkComponent(label: "Retention", href: "/reports/retention", icon: "↻")
                .withBadgeCount(12),
        ]).startCollapsed()

    // Renders nothing at all: `shouldRender` is false for an empty section.
    let archived = SidebarSectionComponent(title: "Archived")

    return SidebarComponent(currentPath: currentPath)
        .with(\.brand, .markup(raw("<strong>Acme</strong>&nbsp;Console")))
        .adding(\.notices, "Billing details expire in 4 days")
        .adding(\.notices, .markup(raw("<a href=\"/status\">Degraded performance</a>")))
        .adding(\.sections, workspace, reports, archived)
        .with(\.footer, SidebarFooterComponent(userName: "Ada Lovelace", role: "Owner"))
        .with(\.content, .markup(raw("<a class=\"sidebar__help\" href=\"/help\">Help &amp; docs</a>")))
}

print("=== sidebar: /projects is the current page ===")
print(buildSidebar(currentPath: "/projects").render())

print("=== sidebar: no sections at all ===")
print(SidebarComponent(currentPath: "/").render())

print("=== one section on its own, rendered straight from the tree ===")
print(SidebarSectionComponent(
    title: "Workspace",
    links: [SidebarLinkComponent(label: "Overview", href: "/", icon: "◱")]).render())

print("=== colocated assets, resolved at build time ===")

for asset in assetManifest([
    SidebarComponent.self, SidebarSectionComponent.self, SidebarLinkComponent.self,
    SidebarFooterComponent.self,
]) {
    print("  \(asset)")
}

print("=== previews ===")
PreviewRegistry.register(SidebarLinkComponentPreview.self)

for preview in PreviewRegistry.all() {
    print("\(preview.group)#\(preview.name): \(preview.build().render())")
}
