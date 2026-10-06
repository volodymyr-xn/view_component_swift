/// Turns parsed template nodes into the Swift extension that renders them.
///
/// The generated body lands *inside* a method of the component, so
/// `<%= label %>` is literally `self.label` — type-checked at build time, with
/// no context object and no runtime lookup. `#sourceLocation` directives point
/// the compiler back at the `.html.erb`, so a typo in a template expression is
/// reported at the template line that wrote it.
public struct SwiftCodeGenerator {
    public struct Options: Sendable {
        public var typeName: String
        public var accessLevel: String
        public var templatePath: String
        public var templateSourcePath: String
        public var sourceHash: UInt64
        public var colocatedAssets: [String]
        public var moduleName: String

        public init(
            typeName: String,
            accessLevel: String,
            templatePath: String,
            templateSourcePath: String,
            sourceHash: UInt64,
            colocatedAssets: [String],
            moduleName: String = "ViewComponent"
        ) {
            self.typeName = typeName
            self.accessLevel = accessLevel
            self.templatePath = templatePath
            self.templateSourcePath = templateSourcePath
            self.sourceHash = sourceHash
            self.colocatedAssets = colocatedAssets
            self.moduleName = moduleName
        }
    }

    private let nodes: [TemplateNode]
    private let options: Options

    public init(nodes: [TemplateNode], options: Options) {
        self.nodes = nodes
        self.options = options
    }

    public static func generate(nodes: [TemplateNode], options: Options) -> String {
        SwiftCodeGenerator(nodes: nodes, options: options).generate()
    }

    public func generate() -> String {
        let modifier = options.accessLevel.isEmpty ? "" : options.accessLevel + " "
        var code = """
        // Generated from \(options.templatePath) by the ViewComponentTemplates plugin.
        // Edits are overwritten on the next build.

        import \(options.moduleName)

        extension \(options.typeName) {
            \(modifier)static var templatePath: String { \(quoted(options.templatePath)) }

            \(modifier)static var templateSourcePath: String { \(quoted(options.templateSourcePath)) }

            \(modifier)static var templateSourceHash: UInt64 { \(options.sourceHash) }

            \(modifier)static var colocatedAssets: [String] { \(assetLiteral) }

            \(modifier)func renderInto<__VCSink: MarkupSink>(_ __vcSink: inout __VCSink) {\n
        """

        code += renderBody(indent: "        ")
        code += "    }\n\n"
        code += bindingMethod(modifier: modifier, indent: "        ")
        code += "}\n"

        return code
    }

    private var assetLiteral: String {
        guard !options.colocatedAssets.isEmpty else { return "[]" }

        return "[" + options.colocatedAssets.map(quoted).joined(separator: ", ") + "]"
    }

    /// `render(x)` is a nested function rather than a library one so that it
    /// can reach the caller's sink: an `inout` parameter cannot be captured by
    /// anything that escapes, but a local function that never escapes may.
    private func renderHelpers(indent: String) -> String {
        """
        \(indent)func render(_ __vcValue: some TemplateEmittable) { emit(&__vcSink, __vcValue) }
        \(indent)func render(_ __vcValue: any ViewComponent) { emit(&__vcSink, __vcValue) }
        \(indent)func render(_ __vcValue: [any ViewComponent]) { emit(&__vcSink, __vcValue) }

        """
    }

    private func renderBody(indent: String) -> String {
        var body = renderHelpers(indent: indent)
        var pendingText = ""

        func flushText() {
            guard !pendingText.isEmpty else { return }

            body += "\(indent)__vcSink.put(\(quoted(pendingText)))\n"
            pendingText = ""
        }

        for node in nodes {
            switch node {
            case .text(let text):
                pendingText += text

            case .statement(let code, let line):
                flushText()
                body += sourceLocation(line: line, indent: indent)
                body += "\(indent)\(code)\n"

            case .escapedOutput(let code, let line):
                flushText()
                body += sourceLocation(line: line, indent: indent)
                body += "\(indent)emit(&__vcSink, \(code))\n"

            case .rawOutput(let code, let line):
                flushText()
                body += sourceLocation(line: line, indent: indent)
                body += "\(indent)emit(&__vcSink, raw(\(code)))\n"
            }
        }

        flushText()

        if body.contains("#sourceLocation") {
            body += "#sourceLocation()\n"
        }

        return body
    }

    private func sourceLocation(line: Int, indent: String) -> String {
        guard !options.templateSourcePath.isEmpty else { return "" }

        return "#sourceLocation(file: \(quoted(options.templateSourcePath)), line: \(line))\n"
    }

    private func bindingMethod(modifier: String, indent: String) -> String {
        let bindings = BindingHarvester.bindings(in: nodes)
        var method = "    \(modifier)func templateBinding(_ __vcName: String) -> TemplateValue? {\n"

        guard !bindings.isEmpty else {
            return method + "\(indent)nil\n    }\n"
        }

        method += "\(indent)switch __vcName {\n"

        for binding in bindings {
            method += "\(indent)case \(quoted(binding.name)):\n"
            method += sourceLocation(line: binding.line, indent: indent)
            method += "\(indent)    return TemplateValue(reflecting: \(binding.callExpression) as Any)\n"
        }

        method += "\(indent)default:\n\(indent)    return nil\n\(indent)}\n    }\n"

        if method.contains("#sourceLocation") {
            method += "#sourceLocation()\n"
        }

        return method
    }

    private func quoted(_ text: String) -> String {
        var literal = "\""

        for character in text {
            switch character {
            case "\\": literal += "\\\\"
            case "\"": literal += "\\\""
            case "\n": literal += "\\n"
            case "\r": literal += "\\r"
            case "\t": literal += "\\t"
            case "\0": literal += "\\0"
            default: literal.append(character)
            }
        }

        return literal + "\""
    }
}
