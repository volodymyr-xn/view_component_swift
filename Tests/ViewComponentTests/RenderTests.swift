import Testing
import ViewComponent
import ViewComponentTesting

@Suite struct RenderTests {
    @Test func rendersAnExpressionAgainstTheComponent() throws {
        let link = SidebarLinkComponent(label: "Overview", state: "active")

        try assertRendersEqualNormalized(
            link, "<a class=\"sidebar__link sidebar__link--active\" href=\"#\">Overview</a>")
    }

    @Test func escapesInterpolatedText() throws {
        let link = SidebarLinkComponent(label: "Q&A <beta>", state: "muted")

        try assertIncludes(link, "Q&amp;A &lt;beta&gt;")
        try assertExcludes(link, "<beta>")
    }

    @Test func honoursTheTagVocabulary() throws {
        let badge = SidebarBadgeComponent(
            text: "a & b", markup: "<em>markup</em>", safe: raw("<b>safe</b>"))

        try assertIncludes(badge, "<p>a &amp; b</p>")
        try assertIncludes(badge, "<p><em>markup</em></p>")
        try assertIncludes(badge, "<p><b>safe</b></p>")
        try assertIncludes(badge, "<p>3</p>")
        try assertExcludes(badge, "discarded")
        try assertIncludes(badge, "<span><% literal %></span>")
    }

    @Test func rendersChildrenIntoTheSameSink() throws {
        let nav = SidebarNavComponent(
            title: "Workspace",
            links: [
                SidebarLinkComponent(label: "Overview", state: "active"),
                SidebarLinkComponent(label: "Projects", state: "muted"),
            ],
            footer: SidebarLinkComponent(label: "More", state: "muted")
        )

        try assertIncludes(nav, "<li><a class=\"sidebar__link sidebar__link--active\" href=\"#\">Overview</a>")
        try assertIncludes(nav, "<li><a class=\"sidebar__link sidebar__link--muted\" href=\"#\">Projects</a>")
        try assertIncludes(nav, "class=\"sidebar__nav-footer\"")
        try assertHasElement(nav, tag: "ul", attributes: ["data-title": "Workspace"])
    }

    @Test func shouldRenderSuppressesTheWholeComponent() {
        #expect(SidebarNavComponent(title: "Archived").render() == "")
    }

    @Test func slotsCarryTextAndMarkup() throws {
        let group = SidebarGroupComponent()
            .with(\.heading, .markup(raw("<strong>Reports</strong>")))
            .with(\.content, "2 unread")
            .adding(\.links, SidebarLinkComponent(label: "Revenue", state: "muted"))

        try assertIncludes(group, "<h2 class=\"sidebar__group-heading\"><strong>Reports</strong></h2>")
        try assertIncludes(group, "<div class=\"sidebar__group-body\">2 unread</div>")
        try assertIncludes(group, "sidebar__link--muted")
    }

    @Test func emptySlotsCollapse() throws {
        try assertExcludes(SidebarGroupComponent(), "sidebar__group-heading")
        try assertExcludes(SidebarGroupComponent(), "sidebar__group-links")
    }

    @Test func rendersExistentialChildren() throws {
        let shell = SidebarShellComponent(
            children: [
                SidebarLinkComponent(label: "Overview", state: "active"),
                SidebarGroupComponent().with(\.content, "body"),
            ],
            lead: SidebarLinkComponent(label: "Lead", state: "muted"))

        try assertIncludes(shell, "class=\"sidebar__shell-lead\"")
        try assertIncludes(shell, "sidebar__link--muted")
        try assertIncludes(shell, "sidebar__link--active")
        try assertIncludes(shell, "class=\"sidebar__group-body\">body</div>")
    }

    @Test func exposesTheTemplateItResolved() {
        #expect(SidebarLinkComponent.templatePath == "Components/sidebar_link_component.html.erb")
        #expect(SidebarGroupComponent.templatePath
            == "Components/sidebar_group_component/sidebar_group_component.html.erb")
        #expect(SidebarGroupComponent.colocatedAssets
            == ["Components/sidebar_group_component/sidebar_group_component.css"])
    }
}
