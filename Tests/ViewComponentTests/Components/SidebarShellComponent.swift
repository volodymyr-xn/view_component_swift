import ViewComponent

/// Holds children as existentials, which is what a shell that accepts any
/// sidebar component has to do.
struct SidebarShellComponent: ViewComponent {
    var children: [any ViewComponent] = []
    var lead: (any ViewComponent)?
}
