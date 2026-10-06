import ViewComponent

struct SidebarBadgeComponent: ViewComponent {
    var text: String
    var markup: String
    var safe: SafeString
    var count = 3
}
