import ViewComponent

/// A single navigation entry. Lives in its parent's sidecar directory, which
/// is all it takes for the plugin to find its own template next to it.
struct SidebarLinkComponent: ViewComponent {
    var label: String
    var href: String
    var icon: String
    var badgeCount = 0

    /// Pushed down by the parent section in its `beforeRender`.
    var currentPath = ""

    private var isActive = false

    init(label: String, href: String, icon: String) {
        self.label = label
        self.href = href
        self.icon = icon
    }

    func withBadgeCount(_ count: Int) -> Self {
        with(\.badgeCount, count)
    }

    mutating func beforeRender() {
        isActive = !currentPath.isEmpty && currentPath == href
    }

    var cssClass: String {
        isActive ? "sidebar__link sidebar__link--active" : "sidebar__link"
    }

    var ariaCurrent: String {
        isActive ? "page" : "false"
    }

    var hasBadge: Bool {
        badgeCount > 0
    }
}
