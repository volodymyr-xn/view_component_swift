import Testing
@testable import ViewComponentTemplateSyntax

/// The sidebar-only rule is the build failing, not a runtime check, so what it
/// accepts and rejects is worth pinning down.
@Suite struct SidebarComponentRuleTests {
    @Test func acceptsSidebarComponents() throws {
        try SidebarComponentRule.validate(
            typeName: "SidebarLinkComponent",
            directives: TemplateDirectives(),
            templateName: "sidebar_link_component.html.erb")
    }

    @Test func rejectsEverythingElse() {
        #expect(throws: TemplateSyntaxError.self) {
            try SidebarComponentRule.validate(
                typeName: "CardComponent",
                directives: TemplateDirectives(),
                templateName: "card_component.html.erb")
        }
    }

    @Test func namesTheFixInTheDiagnostic() {
        do {
            try SidebarComponentRule.validate(
                typeName: "CardComponent",
                directives: TemplateDirectives(),
                templateName: "card_component.html.erb")
            Issue.record("expected the rule to reject CardComponent")
        } catch let failure as TemplateSyntaxError {
            #expect(failure.message.contains("`CardComponent` is not a sidebar component"))
            #expect(failure.message.contains("<%# kind: any %>"))
            #expect(failure.templateName == "card_component.html.erb")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func letsATemplateOptOut() throws {
        try SidebarComponentRule.validate(
            typeName: "CardComponent",
            directives: TemplateDirectives(kind: "any"),
            templateName: "card_component.html.erb")
    }

    @Test func readsTheOptOutFromTheTemplateItself() {
        let directives = TemplateDirectives.scan("<%# kind: any %>\n<p><%= label %></p>")

        #expect(directives.kind == "any")
        #expect(!directives.enforcesSidebarKind)
    }
}
