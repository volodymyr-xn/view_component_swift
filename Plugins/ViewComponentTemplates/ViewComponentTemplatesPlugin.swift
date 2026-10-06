import Foundation
import PackagePlugin

/// Compiles every `.html.erb` sidecar in a target into Swift before the target
/// itself is built, which is what makes a template expression a compile error
/// rather than a 500.
@main
struct ViewComponentTemplatesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }

        let templates = templateFiles(in: sourceTarget.directoryURL)

        guard !templates.isEmpty else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL
        let outputs = templates.map { template in
            outputDirectory.appending(path: typeName(forTemplate: template) + "+Template.swift")
        }

        return [
            .buildCommand(
                displayName: "Compiling \(templates.count) view component template(s) for \(target.name)",
                executable: try context.tool(named: "ViewComponentTemplateCompiler").url,
                arguments: [
                    "--target-dir", sourceTarget.directoryURL.path(percentEncoded: false),
                    "--output-dir", outputDirectory.path(percentEncoded: false),
                ] + templates.map { $0.path(percentEncoded: false) },
                inputFiles: templates,
                outputFiles: outputs
            )
        ]
    }

    private func templateFiles(in directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil)
        var templates: [URL] = []

        while let entry = enumerator?.nextObject() as? URL {
            if entry.lastPathComponent.hasSuffix(".html.erb") {
                templates.append(entry)
            }
        }

        return templates.sorted { $0.path < $1.path }
    }

    /// Mirrors `TemplateNaming.typeName(fromStem:)`, which the plugin cannot
    /// import: plugins may only depend on tools, not on library targets.
    private func typeName(forTemplate template: URL) -> String {
        let source = (try? String(contentsOf: template, encoding: .utf8)) ?? ""

        if let declared = declaredComponentType(in: source) {
            return declared
        }

        let stem = template.lastPathComponent.replacingOccurrences(of: ".html.erb", with: "")
        let initialisms = [
            "HTTPS", "HTML", "HTTP", "JSON", "UUID", "SVG", "XML", "CSS", "PDF",
            "SQL", "URL", "URI", "API", "CLI", "UI", "ID", "IO", "JS",
        ]

        return stem.split(separator: "_").map { word in
            let uppercased = word.uppercased()

            if initialisms.contains(uppercased) {
                return uppercased
            }

            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined()
    }

    private func declaredComponentType(in source: String) -> String? {
        guard let range = source.range(of: "<%# component:") else { return nil }

        let remainder = source[range.upperBound...]

        guard let end = remainder.range(of: "%>") else { return nil }

        return String(remainder[remainder.startIndex..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
