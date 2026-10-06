import ViewComponent

/// Fills the sidebar's single-component `footer` slot.
struct SidebarFooterComponent: ViewComponent {
    var userName: String
    var role: String

    var initials: String {
        userName.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }
}
