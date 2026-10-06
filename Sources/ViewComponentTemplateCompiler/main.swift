import Foundation
import ViewComponentTemplateSyntax

/// Compiles the `.html.erb` sidecars of one target into Swift extensions.
///
///   view-component-template-compiler --target-dir DIR --output-dir DIR \
///       [--module NAME] TEMPLATE...
///
/// Invoked by the ViewComponentTemplates build tool plugin; there is no reason
/// to run it by hand except to inspect what it generates.
struct CompilerArguments {
    var targetDirectory = ""
    var outputDirectory = ""
    var moduleName = "ViewComponent"
    var templates: [String] = []

    static func parse(_ arguments: [String]) -> CompilerArguments {
        var parsed = CompilerArguments()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--target-dir":
                index += 1
                parsed.targetDirectory = index < arguments.count ? arguments[index] : ""
            case "--output-dir":
                index += 1
                parsed.outputDirectory = index < arguments.count ? arguments[index] : ""
            case "--module":
                index += 1
                parsed.moduleName = index < arguments.count ? arguments[index] : "ViewComponent"
            default:
                parsed.templates.append(arguments[index])
            }

            index += 1
        }

        return parsed
    }
}

/// Finds the access level a component type is declared with, so the generated
/// extension matches it: a public component needs public witnesses, and an
/// internal one refuses them.
struct AccessLevelIndex {
    private let sources: [String]

    init(targetDirectory: String) {
        var sources: [String] = []
        let enumerator = FileManager.default.enumerator(atPath: targetDirectory)

        while let entry = enumerator?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }

            let path = (targetDirectory as NSString).appendingPathComponent(entry)

            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                sources.append(contents)
            }
        }

        self.sources = sources
    }

    func accessLevel(of typeName: String) -> String {
        let kinds = ["struct", "final class", "class", "actor", "enum"]

        for source in sources {
            for kind in kinds {
                for modifier in ["public", "package", "open"] {
                    if source.contains("\(modifier) \(kind) \(typeName):")
                        || source.contains("\(modifier) \(kind) \(typeName) ") {
                        return modifier == "open" ? "public" : modifier
                    }
                }
            }
        }

        return ""
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: view-component: " + message + "\n").utf8))
    exit(1)
}

let arguments = CompilerArguments.parse(Array(CommandLine.arguments.dropFirst()))

guard !arguments.outputDirectory.isEmpty else {
    fail("--output-dir is required")
}

try? FileManager.default.createDirectory(
    atPath: arguments.outputDirectory, withIntermediateDirectories: true)

let accessLevels = AccessLevelIndex(targetDirectory: arguments.targetDirectory)

for templatePath in arguments.templates {
    guard let source = try? String(contentsOfFile: templatePath, encoding: .utf8) else {
        fail("cannot read \(templatePath)")
    }

    let fileName = (templatePath as NSString).lastPathComponent
    let stem = fileName
        .replacingOccurrences(of: ".html.erb", with: "")
        .replacingOccurrences(of: ".erb", with: "")
    let directives = TemplateDirectives.scan(source)
    let typeName = directives.componentType ?? TemplateNaming.typeName(fromStem: stem)

    do {
        try SidebarComponentRule.validate(
            typeName: typeName, directives: directives, templateName: templatePath)
    } catch let ruleError as TemplateSyntaxError {
        fail(ruleError.description)
    }

    let nodes: [TemplateNode]

    do {
        nodes = try ErbParser.parse(source, templateName: fileName)
    } catch let syntaxError as TemplateSyntaxError {
        fail(syntaxError.description)
    }

    let templateDirectory = (templatePath as NSString).deletingLastPathComponent
    let colocatedAssets = [".css", ".js"].compactMap { extensionName -> String? in
        let assetPath = (templateDirectory as NSString)
            .appendingPathComponent(stem + extensionName)

        guard FileManager.default.fileExists(atPath: assetPath) else { return nil }

        return relativePath(of: assetPath, from: arguments.targetDirectory)
    }

    let generated = SwiftCodeGenerator.generate(
        nodes: nodes,
        options: SwiftCodeGenerator.Options(
            typeName: typeName,
            accessLevel: directives.accessLevel ?? accessLevels.accessLevel(of: typeName),
            templatePath: relativePath(of: templatePath, from: arguments.targetDirectory),
            templateSourcePath: templatePath,
            sourceHash: TemplateSourceHash.of(source),
            colocatedAssets: colocatedAssets,
            moduleName: arguments.moduleName
        )
    )

    let outputPath = (arguments.outputDirectory as NSString)
        .appendingPathComponent("\(typeName)+Template.swift")

    if let existing = try? String(contentsOfFile: outputPath, encoding: .utf8),
       existing == generated {
        continue
    }

    do {
        try generated.write(toFile: outputPath, atomically: true, encoding: .utf8)
    } catch {
        fail("cannot write \(outputPath): \(error)")
    }
}

func relativePath(of path: String, from base: String) -> String {
    guard !base.isEmpty, path.hasPrefix(base) else {
        return (path as NSString).lastPathComponent
    }

    return String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}
