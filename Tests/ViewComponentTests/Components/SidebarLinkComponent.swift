import ViewComponent

struct SidebarLinkComponent: ViewComponent {
    var label: String
    var state: String
    var href = "#"

    var cssClass: String { "sidebar__link sidebar__link--\(state)" }
}
