import Foundation
import ViewComponentTemplateSyntax

/// Folds the parser's flat node list into the block tree the runtime walks.
struct StatementBuilder {
    let templateName: String

    private struct Frame {
        enum Kind {
            case conditional(line: Int)
            case loop(variable: String, sequence: String, line: Int)
        }

        let kind: Kind
        var branches: [RuntimeTemplate.Branch]
        var pendingCondition: RuntimeTemplate.Branch.Condition?
        var body: [RuntimeTemplate.Statement]
    }

    private struct BuildState {
        var root: [RuntimeTemplate.Statement] = []
        var frames: [Frame] = []

        mutating func append(_ statement: RuntimeTemplate.Statement) {
            if frames.isEmpty {
                root.append(statement)
            } else {
                frames[frames.count - 1].body.append(statement)
            }
        }
    }

    func build(_ nodes: [TemplateNode]) throws -> [RuntimeTemplate.Statement] {
        var state = BuildState()

        for node in nodes {
            switch node {
            case .text(let text):
                state.append(.text(text))

            case .escapedOutput(let expression, let line):
                state.append(.output(expression: expression, escaped: true, line: line))

            case .rawOutput(let expression, let line):
                state.append(.output(expression: expression, escaped: false, line: line))

            case .statement(let code, let line):
                try handle(code, line: line, state: &state)
            }
        }

        guard state.frames.isEmpty else {
            throw TemplateRuntimeError(
                templateName: templateName, line: 0,
                message: "unbalanced `{` in template — \(state.frames.count) block(s) left open")
        }

        return state.root
    }

    private func handle(_ code: String, line: Int, state: inout BuildState) throws {
        let statement = code.trimmingCharacters(in: .whitespacesAndNewlines)

        if statement.hasPrefix("if ") {
            state.frames.append(Frame(
                kind: .conditional(line: line),
                branches: [],
                pendingCondition: try condition(from: String(statement.dropFirst(3)), line: line),
                body: []
            ))

            return
        }

        if statement.hasPrefix("for ") {
            let header = String(statement.dropFirst(4)).strippedBlockBrace

            guard let range = header.range(of: " in ") else {
                throw error(line, "expected `for <name> in <expression> {`")
            }

            state.frames.append(Frame(
                kind: .loop(
                    variable: String(header[header.startIndex..<range.lowerBound])
                        .trimmingCharacters(in: .whitespaces),
                    sequence: String(header[range.upperBound...])
                        .trimmingCharacters(in: .whitespaces),
                    line: line
                ),
                branches: [],
                pendingCondition: nil,
                body: []
            ))

            return
        }

        if statement.hasPrefix("}") {
            guard var frame = state.frames.popLast() else {
                throw error(line, "`}` with no open block")
            }

            let remainder = String(statement.dropFirst()).trimmingCharacters(in: .whitespaces)

            switch frame.kind {
            case .conditional(let openedAt):
                frame.branches.append(
                    RuntimeTemplate.Branch(condition: frame.pendingCondition, body: frame.body))
                frame.body = []
                frame.pendingCondition = nil

                if remainder.hasPrefix("else if ") {
                    frame.pendingCondition = try condition(
                        from: String(remainder.dropFirst(8)), line: line)
                    state.frames.append(frame)

                    return
                }

                if remainder.hasPrefix("else") {
                    state.frames.append(frame)

                    return
                }

                state.append(.conditional(branches: frame.branches, line: openedAt))

            case .loop(let variable, let sequence, let openedAt):
                state.append(.loop(
                    variable: variable, sequence: sequence, body: frame.body, line: openedAt))
            }

            return
        }

        if statement.hasPrefix("render(") {
            let inner = statement.dropFirst("render(".count)

            guard let closing = inner.lastIndex(of: ")") else {
                throw error(line, "expected `)` to close `render(`")
            }

            state.append(.renderCall(expression: String(inner[inner.startIndex..<closing]), line: line))

            return
        }

        throw error(line, "`\(statement)` is not supported by the hot-reload backend — "
            + "rebuild to pick up the change, or move the logic onto the component")
    }

    private func condition(from source: String, line: Int) throws -> RuntimeTemplate.Branch.Condition {
        let header = source.strippedBlockBrace

        guard header.hasPrefix("let ") else {
            return .expression(header)
        }

        let binding = String(header.dropFirst(4)).trimmingCharacters(in: .whitespaces)

        guard let assignment = binding.firstIndex(of: "=") else {
            return .optionalBinding(name: binding, expression: binding)
        }

        return .optionalBinding(
            name: String(binding[binding.startIndex..<assignment])
                .trimmingCharacters(in: .whitespaces),
            expression: String(binding[binding.index(after: assignment)...])
                .trimmingCharacters(in: .whitespaces)
        )
    }

    private func error(_ line: Int, _ message: String) -> TemplateRuntimeError {
        TemplateRuntimeError(templateName: templateName, line: line, message: message)
    }
}

extension String {
    var strippedBlockBrace: String {
        var result = trimmingCharacters(in: .whitespacesAndNewlines)

        while result.hasSuffix("{") {
            result = String(result.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}
