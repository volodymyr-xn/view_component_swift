/// Parses ERB source into template nodes.
///
/// Recognised tags:
///   `<% code %>`    statement, emitted verbatim
///   `<%= expr %>`   expression, stringified and HTML-escaped
///   `<%== expr %>`  expression, emitted verbatim
///   `<%# text %>`   comment, discarded
///   `<%%`           a literal `<%`
///   `<%-` / `-%>`   trim preceding indentation / the following newline
///
/// A tag body may not contain the literal `%>`, including inside a string.
public struct ErbParser {
    private let source: [Character]
    private let templateName: String

    public init(source: String, templateName: String) {
        self.source = Array(source)
        self.templateName = templateName
    }

    /// Parses `source`, or throws a `TemplateSyntaxError` naming the line.
    ///
    /// Lines holding nothing but a control tag are trimmed away unless the
    /// template asks to keep them with `<%# whitespace: keep %>`; see
    /// `TemplateWhitespace`.
    public static func parse(_ source: String, templateName: String) throws -> [TemplateNode] {
        let nodes = try ErbParser(source: source, templateName: templateName).parse()

        guard TemplateDirectives.scan(source).trimsStandaloneTags else { return nodes }

        return TemplateWhitespace.trimmingStandaloneTags(nodes)
    }

    /// Parses without the whitespace pass, for tests and tooling that need the
    /// tags exactly as they were written.
    public static func parseVerbatim(_ source: String, templateName: String) throws -> [TemplateNode] {
        try ErbParser(source: source, templateName: templateName).parse()
    }

    public func parse() throws -> [TemplateNode] {
        var nodes: [TemplateNode] = []
        var literal = ""
        var cursor = 0

        func flushLiteral() {
            guard !literal.isEmpty else { return }

            nodes.append(.text(literal))
            literal = ""
        }

        while cursor < source.count {
            guard let tagOpen = indexOfTagOpen(from: cursor) else {
                literal.append(contentsOf: source[cursor...])
                break
            }

            literal.append(contentsOf: source[cursor..<tagOpen])

            if tagOpen + 2 < source.count, source[tagOpen + 2] == "%" {
                literal += "<%"
                cursor = tagOpen + 3
                continue
            }

            var bodyStart = tagOpen + 2
            var trimLeft = false

            if bodyStart < source.count, source[bodyStart] == "-" {
                trimLeft = true
                bodyStart += 1
            }

            var kind = TagKind.statement

            if bodyStart < source.count, source[bodyStart] == "=" {
                bodyStart += 1
                kind = .escapedOutput

                if bodyStart < source.count, source[bodyStart] == "=" {
                    bodyStart += 1
                    kind = .rawOutput
                }
            } else if bodyStart < source.count, source[bodyStart] == "#" {
                bodyStart += 1
                kind = .comment
            }

            guard let tagClose = indexOfTagClose(from: bodyStart) else {
                throw error(at: tagOpen, "unterminated template tag, expected a closing `%>`")
            }

            var bodyEnd = tagClose
            var trimRight = false

            if bodyEnd > bodyStart, source[bodyEnd - 1] == "-" {
                trimRight = true
                bodyEnd -= 1
            }

            if trimLeft {
                literal = String(literal.reversed().drop { $0 == " " || $0 == "\t" }.reversed())
            }

            flushLiteral()

            let tagBody = String(source[bodyStart..<bodyEnd])
            let line = lineNumber(at: tagOpen)

            switch kind {
            case .statement:
                if !tagBody.trimmed.isEmpty {
                    nodes.append(.statement(tagBody.trimmed, line: line))
                }

            case .escapedOutput:
                try requireExpression(tagBody, at: tagOpen, opener: "<%=")
                nodes.append(.escapedOutput(tagBody.trimmed, line: line))

            case .rawOutput:
                try requireExpression(tagBody, at: tagOpen, opener: "<%==")
                nodes.append(.rawOutput(tagBody.trimmed, line: line))

            case .comment:
                break
            }

            cursor = tagClose + 2

            if trimRight {
                cursor = skipOneNewline(from: cursor)
            }
        }

        flushLiteral()

        return nodes
    }

    private enum TagKind {
        case statement
        case escapedOutput
        case rawOutput
        case comment
    }

    private func requireExpression(_ tagBody: String, at offset: Int, opener: String) throws {
        guard tagBody.trimmed.isEmpty else { return }

        throw error(at: offset, "empty `\(opener)` tag, expected an expression")
    }

    private func error(at offset: Int, _ message: String) -> TemplateSyntaxError {
        TemplateSyntaxError(templateName: templateName, line: lineNumber(at: offset), message: message)
    }

    private func indexOfTagOpen(from start: Int) -> Int? {
        guard source.count >= 2 else { return nil }

        var index = start

        while index < source.count - 1 {
            if source[index] == "<" && source[index + 1] == "%" {
                return index
            }

            index += 1
        }

        return nil
    }

    private func indexOfTagClose(from start: Int) -> Int? {
        guard source.count >= 2 else { return nil }

        var index = start

        while index < source.count - 1 {
            if source[index] == "%" && source[index + 1] == ">" {
                return index
            }

            index += 1
        }

        return nil
    }

    private func skipOneNewline(from start: Int) -> Int {
        var cursor = start

        if cursor < source.count, source[cursor] == "\r" {
            cursor += 1
        }

        if cursor < source.count, source[cursor] == "\n" {
            cursor += 1
        }

        return cursor
    }

    private func lineNumber(at offset: Int) -> Int {
        var line = 1

        for index in 0..<min(offset, source.count) where source[index] == "\n" {
            line += 1
        }

        return line
    }
}

extension String {
    var trimmed: String {
        let characters = Array(self)
        var start = 0
        var end = characters.count

        while start < end, characters[start].isTemplateWhitespace {
            start += 1
        }

        while end > start, characters[end - 1].isTemplateWhitespace {
            end -= 1
        }

        return String(characters[start..<end])
    }
}

extension Character {
    var isTemplateWhitespace: Bool {
        self == " " || self == "\t" || self == "\n" || self == "\r"
    }
}
