import ViewComponent

/// Previews are registered rather than discovered: Swift cannot enumerate the
/// types in a module the way D's compile-time reflection can.
struct SidebarLinkComponentPreview: ComponentPreview {
    static var previews: [PreviewCase] {
        [
            PreviewCase("plain") {
                SidebarLinkComponent(label: "Overview", href: "/", icon: "◱")
            },
            PreviewCase("with badge") {
                SidebarLinkComponent(label: "Projects", href: "/projects", icon: "▤")
                    .withBadgeCount(3)
            },
            PreviewCase("active") {
                var link = SidebarLinkComponent(label: "Projects", href: "/projects", icon: "▤")
                link.currentPath = "/projects"

                return link
            },
        ]
    }
}
