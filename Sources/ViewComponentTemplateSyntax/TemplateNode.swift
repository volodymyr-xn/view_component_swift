/// One piece of a parsed ERB template.
///
/// The same node list feeds both backends: the code generator turns it into
/// Swift statements at build time, and the hot-reload runtime walks it
/// directly. Keeping one parser is what keeps the two backends honest.
public enum TemplateNode: Equatable, Sendable {
    /// Literal markup, written to the sink verbatim.
    case text(String)
    /// `<% code %>` — a Swift statement.
    case statement(String, line: Int)
    /// `<%= expr %>` — a Swift expression, stringified and HTML-escaped.
    case escapedOutput(String, line: Int)
    /// `<%== expr %>` — a Swift expression, emitted unescaped.
    case rawOutput(String, line: Int)
}

/// A malformed template, reported with the file and line that caused it.
public struct TemplateSyntaxError: Error, CustomStringConvertible, Equatable {
    public let templateName: String
    public let line: Int
    public let message: String

    public init(templateName: String, line: Int, message: String) {
        self.templateName = templateName
        self.line = line
        self.message = message
    }

    public var description: String {
        "\(templateName):\(line): \(message)"
    }
}
