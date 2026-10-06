import Testing
@testable import ViewComponentTemplateSyntax

@Suite struct SwiftCodeGeneratorTests {
    private func generate(_ source: String, accessLevel: String = "") throws -> String {
        SwiftCodeGenerator.generate(
            nodes: try ErbParser.parse(source, templateName: "button_component.html.erb"),
            options: SwiftCodeGenerator.Options(
                typeName: "ButtonComponent",
                accessLevel: accessLevel,
                templatePath: "Components/button_component.html.erb",
                templateSourcePath: "",
                sourceHash: 42,
                colocatedAssets: []
            )
        )
    }

    @Test func writesLiteralsAsOneSinkCall() throws {
        let code = try generate("<p>a</p><p>b</p>")

        #expect(code.contains(#"__vcSink.put("<p>a</p><p>b</p>")"#))
    }

    @Test func escapesStringLiteralsForSwift() throws {
        let code = try generate("<a href=\"#\">\n")

        #expect(code.contains(##"put("<a href=\"#\">\n")"##))
    }

    @Test func emitsExpressionsThroughTheEscapingDispatcher() throws {
        #expect(try generate("<%= label %>").contains("emit(&__vcSink, label)"))
        #expect(try generate("<%== label %>").contains("emit(&__vcSink, raw(label))"))
    }

    @Test func passesStatementsThroughUntouched() throws {
        #expect(try generate("<% if isActive { %><% } %>").contains("if isActive {"))
    }

    @Test func matchesTheComponentAccessLevel() throws {
        #expect(try generate("<%= label %>", accessLevel: "public")
            .contains("public func renderInto<__VCSink: MarkupSink>(_ __vcSink: inout __VCSink)"))
        #expect(try generate("<%= label %>")
            .contains("    func renderInto<__VCSink: MarkupSink>(_ __vcSink: inout __VCSink)"))
    }

    @Test func carriesTheSourceHashForHotReload() throws {
        #expect(try generate("<%= label %>").contains("templateSourceHash: UInt64 { 42 }"))
    }
}
