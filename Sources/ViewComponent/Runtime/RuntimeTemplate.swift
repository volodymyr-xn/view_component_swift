import Foundation
import ViewComponentTemplateSyntax

/// A template read back from disk after it was edited, rendered by walking the
/// same node list the code generator compiles.
///
/// The statement subset is deliberately narrow: conditionals, `for` loops and
/// `render(...)`. Everything else is a compile-time concern, and asking an
/// interpreter to fake it is how two backends drift apart.
public final class RuntimeTemplate {
    indirect enum Statement {
        case text(String)
        case output(expression: String, escaped: Bool, line: Int)
        case conditional(branches: [Branch], line: Int)
        case loop(variable: String, sequence: String, body: [Statement], line: Int)
        case renderCall(expression: String, line: Int)
    }

    struct Branch {
        enum Condition {
            case expression(String)
            case optionalBinding(name: String, expression: String)
        }

        let condition: Condition?
        let body: [Statement]
    }

    let templateName: String
    private let statements: [Statement]

    public init(nodes: [TemplateNode], templateName: String) throws {
        self.templateName = templateName
        statements = try StatementBuilder(templateName: templateName).build(nodes)
    }

    public convenience init(source: String, templateName: String) throws {
        try self.init(
            nodes: try ErbParser.parse(source, templateName: templateName),
            templateName: templateName
        )
    }

    public func render(_ component: any ViewComponent, into sink: inout some MarkupSink) {
        var scope = EvaluationScope(component: component)

        do {
            try run(statements, scope: &scope, into: &sink)
        } catch let failure as TemplateRuntimeError {
            sink.put(Self.errorMarkup(failure.description))
        } catch {
            sink.put(Self.errorMarkup("\(templateName): \(error)"))
        }
    }

    /// A hot-reload failure is shown in place: a stale render that silently
    /// ignores the edit is worse than a loud one.
    static func errorMarkup(_ message: String) -> String {
        "<pre class=\"view-component-error\" style=\"white-space:pre-wrap;color:#b00020\">"
            + escapeHTML("view-component: " + message) + "</pre>"
    }

    private func run(
        _ statements: [Statement],
        scope: inout EvaluationScope,
        into sink: inout some MarkupSink
    ) throws {
        for statement in statements {
            switch statement {
            case .text(let text):
                sink.put(text)

            case .output(let expression, let escaped, let line):
                let value = try evaluate(expression, scope: scope, line: line)

                if escaped {
                    value.emitInto(&sink)
                } else {
                    sink.put(value.text)
                }

            case .renderCall(let expression, let line):
                try evaluate(expression, scope: scope, line: line).emitInto(&sink)

            case .conditional(let branches, let line):
                try runConditional(branches, line: line, scope: &scope, into: &sink)

            case .loop(let variable, let sequence, let body, let line):
                let value = try evaluate(sequence, scope: scope, line: line)

                guard case .list(let elements) = value else {
                    throw TemplateRuntimeError(
                        templateName: templateName, line: line,
                        message: "`\(sequence)` is not a sequence")
                }

                for element in elements {
                    var childScope = scope
                    childScope.locals[variable] = element

                    try run(body, scope: &childScope, into: &sink)
                }
            }
        }
    }

    private func runConditional(
        _ branches: [Branch],
        line: Int,
        scope: inout EvaluationScope,
        into sink: inout some MarkupSink
    ) throws {
        for branch in branches {
            guard let condition = branch.condition else {
                try run(branch.body, scope: &scope, into: &sink)

                return
            }

            switch condition {
            case .expression(let expression):
                guard try evaluate(expression, scope: scope, line: line).isTruthy else { continue }

                try run(branch.body, scope: &scope, into: &sink)

                return

            case .optionalBinding(let name, let expression):
                let value = try evaluate(expression, scope: scope, line: line)

                if case .none = value { continue }

                var childScope = scope
                childScope.locals[name] = value

                try run(branch.body, scope: &childScope, into: &sink)

                return
            }
        }
    }

    private func evaluate(_ expression: String, scope: EvaluationScope, line: Int) throws -> TemplateValue {
        try ExpressionEvaluator.evaluate(
            expression, in: scope, templateName: templateName, line: line)
    }
}
