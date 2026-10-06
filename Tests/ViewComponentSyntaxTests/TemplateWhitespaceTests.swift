import Testing
@testable import ViewComponentTemplateSyntax

/// A control tag that owns its line leaves no trace in the output, so
/// templates need `<%-` only for tags that sit inline among markup.
@Suite struct TemplateWhitespaceTests {
    @Test func dropsTheLineAStandaloneStatementSitsOn() throws {
        let nodes = try ErbParser.parse("<ul>\n  <% if x { %>\n  <li>a</li>\n  <% } %>\n</ul>\n",
                                        templateName: "t.erb")

        #expect(nodes == [
            .text("<ul>\n"),
            .statement("if x {", line: 2),
            .text("  <li>a</li>\n"),
            .statement("}", line: 4),
            .text("</ul>\n"),
        ])
    }

    @Test func leavesInlineStatementsAlone() throws {
        let nodes = try ErbParser.parse("<li><% render(x) %></li>", templateName: "t.erb")

        #expect(nodes == [
            .text("<li>"),
            .statement("render(x)", line: 1),
            .text("</li>"),
        ])
    }

    @Test func neverTrimsAroundOutput() throws {
        let nodes = try ErbParser.parse("a\n<%= label %>\nb\n", templateName: "t.erb")

        #expect(nodes == [
            .text("a\n"),
            .escapedOutput("label", line: 2),
            .text("\nb\n"),
        ])
    }

    @Test func dropsTheLineAStandaloneCommentSatOn() throws {
        let nodes = try ErbParser.parse("a\n  <%# note %>\nb\n", templateName: "t.erb")

        #expect(nodes == [.text("a\n"), .text("b\n")])
    }

    @Test func keepsEverythingWhenTheTemplateAsksTo() throws {
        let source = "<%# whitespace: keep %>\n<ul>\n  <% if x { %>\n  <li>a</li>\n  <% } %>\n</ul>\n"
        let nodes = try ErbParser.parse(source, templateName: "t.erb")

        #expect(nodes.contains(.text("\n<ul>\n  ")))
    }
}
