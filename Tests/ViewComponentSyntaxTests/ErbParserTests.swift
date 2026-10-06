import Testing
@testable import ViewComponentTemplateSyntax

@Suite struct ErbParserTests {
    @Test func splitsTextFromTags() throws {
        let nodes = try ErbParser.parse("<p><%= label %></p>", templateName: "t.erb")

        #expect(nodes == [
            .text("<p>"),
            .escapedOutput("label", line: 1),
            .text("</p>"),
        ])
    }

    @Test func distinguishesEveryTagKind() throws {
        let nodes = try ErbParser.parse(
            "<% code() %><%= escaped %><%== raw %><%# gone %>", templateName: "t.erb")

        #expect(nodes == [
            .statement("code()", line: 1),
            .escapedOutput("escaped", line: 1),
            .rawOutput("raw", line: 1),
        ])
    }

    @Test func keepsALiteralTagOpener() throws {
        let nodes = try ErbParser.parse("<%% literal %>", templateName: "t.erb")

        #expect(nodes == [.text("<% literal %>")])
    }

    @Test func trimsIndentationAndTheFollowingNewline() throws {
        let nodes = try ErbParser.parse("a\n  <%- if x { -%>\nb\n", templateName: "t.erb")

        #expect(nodes == [
            .text("a\n"),
            .statement("if x {", line: 2),
            .text("b\n"),
        ])
    }

    @Test func countsLinesForDiagnostics() throws {
        let nodes = try ErbParser.parse("\n\n<%= label %>", templateName: "t.erb")

        #expect(nodes.contains(.escapedOutput("label", line: 3)))
    }

    @Test func rejectsAnUnterminatedTag() {
        #expect(throws: TemplateSyntaxError.self) {
            try ErbParser.parse("<p><%= label", templateName: "t.erb")
        }
    }

    @Test func rejectsAnEmptyOutputTag() {
        #expect(throws: TemplateSyntaxError.self) {
            try ErbParser.parse("<%=  %>", templateName: "t.erb")
        }
    }
}
