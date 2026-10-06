import Testing
import ViewComponent
import ViewComponentTesting

/// The interpreter used for an edited sidecar, exercised without touching the
/// hot-reload cache or the filesystem.
@Suite struct RuntimeTemplateTests {
    private func render(_ source: String, _ component: some ViewComponent) throws -> String {
        var sink = Sink()
        try RuntimeTemplate(source: source, templateName: "test.html.erb")
            .render(component, into: &sink)

        return sink.markup
    }

    @Test func readsComputedMembersThroughTheGeneratedBindings() throws {
        let markup = try render(
            "<a class=\"<%= cssClass %>\"><%= label %></a>",
            SidebarLinkComponent(label: "Overview", state: "active"))

        #expect(markup == "<a class=\"sidebar__link sidebar__link--active\">Overview</a>")
    }

    @Test func readsStoredMembersTheCompiledTemplateNeverNamed() throws {
        let markup = try render("<%= state %>", SidebarLinkComponent(label: "Overview", state: "muted"))

        #expect(markup == "muted")
    }

    @Test func escapesLikeTheCompiledBackend() throws {
        let badge = SidebarBadgeComponent(
            text: "a & b", markup: "<em>x</em>", safe: raw("<b>y</b>"))

        #expect(try render("<%= text %>", badge) == "a &amp; b")
        #expect(try render("<%== markup %>", badge) == "<em>x</em>")
        #expect(try render("<%= safe %>", badge) == "<b>y</b>")
    }

    @Test func evaluatesConditionals() throws {
        let group = SidebarGroupComponent().with(\.heading, "Reports")
        let source = """
        <% if !heading.isEmpty { %>
        <h2><%= heading %></h2>
        <% } else { %>
        <h2>none</h2>
        <% } %>
        """

        #expect(try render(source, group).contains("<h2>Reports</h2>"))
        #expect(try render(source, SidebarGroupComponent()).contains("<h2>none</h2>"))
    }

    @Test func evaluatesComparisons() throws {
        let badge = SidebarBadgeComponent(text: "", markup: "", safe: raw(""), count: 3)

        #expect(try render("<% if count > 2 { %>big<% } %>", badge) == "big")
        #expect(try render("<% if count == 3 { %>three<% } %>", badge) == "three")
        #expect(try render("<% if count > 9 { %>big<% } %>", badge) == "")
    }

    @Test func loopsOverComponentsAndRendersThem() throws {
        let nav = SidebarNavComponent(
            title: "Workspace",
            links: [
                SidebarLinkComponent(label: "Overview", state: "active"),
                SidebarLinkComponent(label: "Projects", state: "muted"),
            ])
        let markup = try render("<% for link in links { %><li><%= link %></li><% } %>", nav)

        #expect(markup.contains("sidebar__link--active"))
        #expect(markup.contains("sidebar__link--muted"))
        #expect(markup.contains("<li>"))
    }

    @Test func bindsOptionalsWithIfLet() throws {
        let nav = SidebarNavComponent(
            title: "Workspace", footer: SidebarLinkComponent(label: "More", state: "muted"))
        let source = "<% if let footer { %><% render(footer) %><% } %>"

        #expect(try render(source, nav).contains("More"))
        #expect(try render(source, SidebarNavComponent(title: "Workspace")) == "")
    }

    @Test func showsAnUnknownMemberInPlaceRatherThanRenderingStaleMarkup() throws {
        let markup = try render("<%= nope %>", SidebarLinkComponent(label: "Overview", state: "active"))

        #expect(markup.contains("view-component-error"))
        #expect(markup.contains("nope"))
    }

    @Test func rejectsStatementsItCannotHonour() {
        #expect(throws: TemplateRuntimeError.self) {
            try RuntimeTemplate(source: "<% while true { %>x<% } %>", templateName: "test.html.erb")
        }
    }
}
