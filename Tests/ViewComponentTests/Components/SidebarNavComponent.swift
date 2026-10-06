import ViewComponent

struct SidebarNavComponent: ViewComponent {
    var title: String
    var links: [SidebarLinkComponent] = []
    var footer: SidebarLinkComponent?

    func shouldRender() -> Bool {
        !links.isEmpty
    }
}
