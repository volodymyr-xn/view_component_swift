import ViewComponent

/// A titled group of links. Suppresses itself entirely when it holds none.
struct SidebarSectionComponent: ViewComponent {
    var title: String
    var links: [SidebarLinkComponent] = []

    /// Pushed down by the sidebar in its `beforeRender`.
    var currentPath = ""

    /// Derived by `beforeRender`, not passed in — which is why this struct
    /// spells out its initializer instead of taking the memberwise one.
    private var isCollapsed = false

    init(title: String, links: [SidebarLinkComponent] = []) {
        self.title = title
        self.links = links
    }

    func startCollapsed() -> Self {
        var copy = self
        copy.isCollapsed = true

        return copy
    }

    mutating func beforeRender() {
        for index in links.indices {
            links[index].currentPath = currentPath
        }
    }

    func shouldRender() -> Bool {
        !links.isEmpty
    }

    var showsLinks: Bool {
        !isCollapsed
    }

    var cssClass: String {
        isCollapsed ? "sidebar__section sidebar__section--collapsed" : "sidebar__section"
    }

    var totalBadgeCount: Int {
        links.reduce(0) { $0 + $1.badgeCount }
    }
}
