import ViewComponent

/// Root of the sidebar tree, and the example that exercises every slot shape
/// at once:
///
///   brand     a single markup slot
///   notices   a repeatable markup slot
///   sections  a repeatable component slot
///   footer    a single optional component slot
///   content   the content block
struct SidebarComponent: ViewComponent {
    var currentPath: String
    var brand: Content = .empty
    var notices: [Content] = []
    var sections: [SidebarSectionComponent] = []
    var footer: SidebarFooterComponent?
    var content: Content = .empty

    /// Pushes the current path down the tree before anything renders, so a
    /// link does not have to be told twice where it sits.
    mutating func beforeRender() {
        for index in sections.indices {
            sections[index].currentPath = currentPath
        }
    }

    var hasNavigation: Bool {
        sections.contains { !$0.links.isEmpty }
    }
}
