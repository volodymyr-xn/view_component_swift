import Testing
@testable import ViewComponentTemplateSyntax

@Suite struct TemplateNamingTests {
    @Test func snakeCasesComponentNames() {
        #expect(TemplateNaming.snakeCase(from: "ButtonComponent") == "button_component")
        #expect(TemplateNaming.snakeCase(from: "HTMLBlockComponent") == "html_block_component")
        #expect(TemplateNaming.snakeCase(from: "SidebarLinkComponent") == "sidebar_link_component")
    }

    @Test func recoversTheTypeNameFromAStem() {
        #expect(TemplateNaming.typeName(fromStem: "button_component") == "ButtonComponent")
        #expect(TemplateNaming.typeName(fromStem: "html_block_component") == "HTMLBlockComponent")
    }

    @Test func roundTripsEveryNameItCanSpell() {
        for name in ["ButtonComponent", "HTMLBlockComponent", "SidebarSectionComponent"] {
            #expect(TemplateNaming.typeName(fromStem: TemplateNaming.snakeCase(from: name)) == name)
        }
    }
}
