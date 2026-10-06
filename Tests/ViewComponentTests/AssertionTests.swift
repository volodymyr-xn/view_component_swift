import Testing
import ViewComponent
import ViewComponentTesting

@Suite struct AssertionTests {
    private let link = SidebarLinkComponent(label: "Overview", state: "active")

    @Test func includesAndExcludesReportTheRender() {
        #expect(throws: ComponentAssertionFailure.self) {
            try assertIncludes(link, "missing")
        }
        #expect(throws: ComponentAssertionFailure.self) {
            try assertExcludes(link, "sidebar__link--active")
        }
    }

    @Test func normalizedComparisonIgnoresLayout() throws {
        try assertRendersEqualNormalized(
            link, "  <a class=\"sidebar__link sidebar__link--active\"\n href=\"#\">Overview</a>\n")
    }

    @Test func elementMatchingChecksTagAndAttributes() {
        let markup = link.render()

        #expect(hasElement(markup, tag: "a", attributes: ["href": "#"]))
        #expect(hasElement(markup, tag: "a", attributes: ["class": "sidebar__link sidebar__link--active"]))
        #expect(!hasElement(markup, tag: "a", attributes: ["href": "/other"]))
        #expect(!hasElement(markup, tag: "abbr"))
    }
}
