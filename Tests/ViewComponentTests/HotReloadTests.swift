import Foundation
import Testing
import ViewComponent

/// Hot reload swaps in an edited sidecar and nothing else: a template whose
/// bytes still match the compiled one keeps rendering through generated code.
@Suite(.serialized) struct HotReloadTests {
    private let link = SidebarLinkComponent(label: "Overview", state: "active")
    private let compiledMarkup =
        "<a class=\"sidebar__link sidebar__link--active\" href=\"#\">Overview</a>\n"

    private func withTemplate(_ contents: String, _ body: () throws -> Void) throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "view-component-hot-reload-\(UUID().uuidString)")
        let templatePath = root.appending(path: SidebarLinkComponent.templatePath)

        try FileManager.default.createDirectory(
            at: templatePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: templatePath, atomically: true, encoding: .utf8)

        TemplateHotReload.shared.enable(searchPaths: [root.path(percentEncoded: false)])

        defer {
            TemplateHotReload.shared.disable()
            try? FileManager.default.removeItem(at: root)
        }

        try body()
    }

    @Test func rendersAnEditedTemplateWithoutARebuild() throws {
        try withTemplate("<button class=\"<%= cssClass %>\"><%= label %></button>\n") {
            #expect(link.render() == "<button class=\"sidebar__link sidebar__link--active\">Overview</button>\n")
        }
    }

    @Test func leavesUneditedTemplatesOnTheCompiledPath() throws {
        let compiled = try String(
            contentsOfFile: SidebarLinkComponent.templateSourcePath, encoding: .utf8)

        try withTemplate(compiled) {
            #expect(link.render() == compiledMarkup)
        }
    }

    @Test func reportsAnUnsupportedEditInPlace() throws {
        try withTemplate("<% while true { %>x<% } %>\n") {
            let markup = link.render()

            #expect(markup.contains("view-component-error"))
            #expect(markup.contains("not supported by the hot-reload backend"))
        }
    }

    @Test func staysOffUntilItIsSwitchedOn() {
        #expect(link.render() == compiledMarkup)
    }
}
