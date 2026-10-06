/// Drops the line a control tag sits on when the tag is all that is on it.
///
/// `<% if x { %>` alone on a line is markup-free bookkeeping, so leaving its
/// indentation and newline in the output only means every template has to be
/// written `<%- … -%>` to look right. Output tags are never touched: `<%= x %>`
/// on its own line is content, and its newline belongs to the reader.
///
/// `<%- … -%>` still trims explicitly, which is what an *inline* tag needs, and
/// `<%# whitespace: keep %>` opts a template out of the automatic pass.
public enum TemplateWhitespace {
    public static func trimmingStandaloneTags(_ nodes: [TemplateNode]) -> [TemplateNode] {
        var trimmed = nodes

        for boundary in boundaries(in: nodes) {
            guard endsALine(at: boundary.left, in: trimmed),
                  startsALine(at: boundary.right, in: trimmed) else {
                continue
            }

            if boundary.left >= 0, case .text(let text) = trimmed[boundary.left] {
                trimmed[boundary.left] = .text(droppingTrailingIndentation(text))
            }

            if boundary.right < trimmed.count, case .text(let text) = trimmed[boundary.right] {
                trimmed[boundary.right] = .text(droppingLeadingBlankLine(text))
            }
        }

        return trimmed.filter { node in
            guard case .text(let text) = node else { return true }

            return !text.isEmpty
        }
    }

    /// A control tag with the text either side of it, plus the gap a discarded
    /// comment leaves behind as two adjacent text nodes.
    private static func boundaries(in nodes: [TemplateNode]) -> [(left: Int, right: Int)] {
        var boundaries: [(left: Int, right: Int)] = []

        for index in nodes.indices {
            switch nodes[index] {
            case .statement:
                boundaries.append((left: index - 1, right: index + 1))
            case .text:
                guard index > 0, case .text = nodes[index - 1] else { continue }

                boundaries.append((left: index - 1, right: index))
            case .escapedOutput, .rawOutput:
                continue
            }
        }

        return boundaries
    }

    private static func endsALine(at index: Int, in nodes: [TemplateNode]) -> Bool {
        guard index >= 0 else { return true }

        guard case .text(let text) = nodes[index] else { return false }

        let indentation = text.reversed().prefix { $0 == " " || $0 == "\t" }

        return indentation.count == text.count || text.dropLast(indentation.count).hasSuffix("\n")
    }

    private static func startsALine(at index: Int, in nodes: [TemplateNode]) -> Bool {
        guard index < nodes.count else { return true }

        guard case .text(let text) = nodes[index] else { return false }

        let indentation = text.prefix { $0 == " " || $0 == "\t" }
        let remainder = text.dropFirst(indentation.count)

        return remainder.isEmpty || remainder.hasPrefix("\n") || remainder.hasPrefix("\r\n")
    }

    private static func droppingTrailingIndentation(_ text: String) -> String {
        String(text.reversed().drop { $0 == " " || $0 == "\t" }.reversed())
    }

    private static func droppingLeadingBlankLine(_ text: String) -> String {
        var remainder = Substring(text)

        while remainder.first == " " || remainder.first == "\t" {
            remainder = remainder.dropFirst()
        }

        if remainder.first == "\r" {
            remainder = remainder.dropFirst()
        }

        if remainder.first == "\n" {
            remainder = remainder.dropFirst()
        }

        return String(remainder)
    }
}
