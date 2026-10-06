import ViewComponent

struct SidebarGroupComponent: ViewComponent {
    var heading: Content = .empty
    var links: [SidebarLinkComponent] = []
    var content: Content = .empty
}
