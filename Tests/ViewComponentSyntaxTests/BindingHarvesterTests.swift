import Testing
@testable import ViewComponentTemplateSyntax

/// What the harvester keeps decides which members a hot-reloaded template can
/// still read, and what it drops decides whether the generated file compiles.
@Suite struct BindingHarvesterTests {
    private func names(_ source: String) throws -> [String] {
        BindingHarvester.bindings(in: try ErbParser.parse(source, templateName: "t.erb"))
            .map(\.name)
    }

    @Test func collectsOutputExpressions() throws {
        #expect(try names("<%= label %><%== markup %>") == ["label", "markup"])
    }

    @Test func collectsControlFlowConditions() throws {
        #expect(try names("<% if hasBadge { %><% } %>") == ["hasBadge"])
        #expect(try names("<% for link in links { %><% } %>") == ["links"])
    }

    @Test func skipsMembersOfOtherValues() throws {
        #expect(try names("<% if !heading.isEmpty { %><% } %>") == ["heading"])
    }

    @Test func skipsLoopVariables() throws {
        #expect(try names("<% for link in links { %><%= link %><% } %>") == ["links"])
    }

    @Test func skipsNamesTheTemplateBinds() throws {
        #expect(try names("<% let total = count %><%= total %>") == ["count"])
    }

    @Test func keepsTheShorthandOptionalBinding() throws {
        #expect(try names("<% if let footer { %><% } %>") == ["footer"])
    }

    @Test func skipsTypesAndLibraryCalls() throws {
        #expect(try names("<%= raw(markup) %>") == ["markup"])
        #expect(try names("<% render(sections) %>") == ["sections"])
    }

    @Test func recordsCallSyntaxSoTheGeneratedCodeInvokes() throws {
        let bindings = BindingHarvester.bindings(
            in: try ErbParser.parse("<%= badgeCount() %>", templateName: "t.erb"))

        #expect(bindings.first?.callExpression == "badgeCount()")
    }

    @Test func ignoresIdentifiersInsideStringLiterals() throws {
        #expect(try names("<%= label + \"nope\" %>") == ["label"])
    }
}
