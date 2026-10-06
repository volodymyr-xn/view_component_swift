/// A template expression that the hot-reload backend could not evaluate.
public struct TemplateRuntimeError: Error, CustomStringConvertible {
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

/// Names in scope while a hot-reloaded template renders: the component itself,
/// plus whatever the template's own `for` loops and `if let` bindings added.
public struct EvaluationScope {
    public let component: any ViewComponent
    public var locals: [String: TemplateValue]

    public init(component: any ViewComponent, locals: [String: TemplateValue] = [:]) {
        self.component = component
        self.locals = locals
    }

    public func value(named name: String) -> TemplateValue? {
        if let local = locals[name] {
            return local
        }

        return component.templateBinding(name) ?? TemplateValue.reflectedMember(name, of: component)
    }
}

/// Evaluates the expression subset a hot-reloaded template may use.
///
/// Anything the compiled backend accepts is full Swift; this covers what an
/// interpreter can honestly promise — member paths, zero-argument calls,
/// literals, comparisons and boolean logic. Reaching past it is an error the
/// template shows in place rather than a silently wrong render.
public struct ExpressionEvaluator {
    private let tokens: [Token]
    private let templateName: String
    private let line: Int
    private var cursor = 0

    public static func evaluate(
        _ source: String,
        in scope: EvaluationScope,
        templateName: String,
        line: Int
    ) throws -> TemplateValue {
        var evaluator = ExpressionEvaluator(
            tokens: try Tokenizer.tokens(of: source, templateName: templateName, line: line),
            templateName: templateName,
            line: line
        )

        let value = try evaluator.parseOr(scope)

        guard evaluator.cursor == evaluator.tokens.count else {
            throw evaluator.error("unexpected `\(evaluator.tokens[evaluator.cursor].text)` in expression")
        }

        return value
    }

    private init(tokens: [Token], templateName: String, line: Int) {
        self.tokens = tokens
        self.templateName = templateName
        self.line = line
    }

    private mutating func parseOr(_ scope: EvaluationScope) throws -> TemplateValue {
        var left = try parseAnd(scope)

        while match("||") {
            let right = try parseAnd(scope)
            left = .bool(left.isTruthy || right.isTruthy)
        }

        return left
    }

    private mutating func parseAnd(_ scope: EvaluationScope) throws -> TemplateValue {
        var left = try parseComparison(scope)

        while match("&&") {
            let right = try parseComparison(scope)
            left = .bool(left.isTruthy && right.isTruthy)
        }

        return left
    }

    private mutating func parseComparison(_ scope: EvaluationScope) throws -> TemplateValue {
        let left = try parseUnary(scope)

        for symbol in ["==", "!=", "<=", ">=", "<", ">"] where match(symbol) {
            let right = try parseUnary(scope)

            return .bool(try compare(left, right, using: symbol))
        }

        return left
    }

    private mutating func parseUnary(_ scope: EvaluationScope) throws -> TemplateValue {
        if match("!") {
            return .bool(!(try parseUnary(scope).isTruthy))
        }

        return try parsePostfix(scope)
    }

    private mutating func parsePostfix(_ scope: EvaluationScope) throws -> TemplateValue {
        var value = try parsePrimary(scope)

        while match(".") {
            guard let name = takeIdentifier() else {
                throw error("expected a member name after `.`")
            }

            _ = match("(") && match(")")

            guard let member = value.member(name) else {
                throw error("`\(name)` is not readable from a hot-reloaded template")
            }

            value = member
        }

        return value
    }

    private mutating func parsePrimary(_ scope: EvaluationScope) throws -> TemplateValue {
        guard cursor < tokens.count else {
            throw error("unexpected end of expression")
        }

        let token = tokens[cursor]
        cursor += 1

        switch token.kind {
        case .string:
            return .string(token.text)

        case .number:
            if let number = Int(token.text) {
                return .int(number)
            }

            return .double(Double(token.text) ?? 0)

        case .identifier:
            switch token.text {
            case "true": return .bool(true)
            case "false": return .bool(false)
            case "nil": return .none
            case "raw":
                guard match("(") else { throw error("expected `(` after `raw`") }

                let value = try parseOr(scope)

                guard match(")") else { throw error("expected `)` to close `raw(`") }

                return .markup(SafeString(value.text))
            default:
                break
            }

            _ = match("(") && match(")")

            guard let value = scope.value(named: token.text) else {
                throw error("`\(token.text)` is not a member of the component, and no local"
                    + " binding of that name is in scope")
            }

            return value

        case .symbol where token.text == "(":
            let value = try parseOr(scope)

            guard match(")") else { throw error("expected `)`") }

            return value

        case .symbol:
            throw error("unexpected `\(token.text)` in expression")
        }
    }

    private func compare(_ left: TemplateValue, _ right: TemplateValue, using symbol: String) throws -> Bool {
        if case .int(let leftNumber) = left, case .int(let rightNumber) = right {
            return compareNumbers(Double(leftNumber), Double(rightNumber), using: symbol)
        }

        if let leftNumber = numericValue(left), let rightNumber = numericValue(right) {
            return compareNumbers(leftNumber, rightNumber, using: symbol)
        }

        switch symbol {
        case "==": return left.text == right.text
        case "!=": return left.text != right.text
        default:
            throw error("`\(symbol)` needs numbers on both sides")
        }
    }

    private func numericValue(_ value: TemplateValue) -> Double? {
        switch value {
        case .int(let number): Double(number)
        case .double(let number): number
        default: nil
        }
    }

    private func compareNumbers(_ left: Double, _ right: Double, using symbol: String) -> Bool {
        switch symbol {
        case "==": left == right
        case "!=": left != right
        case "<": left < right
        case "<=": left <= right
        case ">": left > right
        default: left >= right
        }
    }

    private mutating func match(_ symbol: String) -> Bool {
        guard cursor < tokens.count, tokens[cursor].kind == .symbol,
              tokens[cursor].text == symbol else {
            return false
        }

        cursor += 1

        return true
    }

    private mutating func takeIdentifier() -> String? {
        guard cursor < tokens.count, tokens[cursor].kind == .identifier else { return nil }

        defer { cursor += 1 }

        return tokens[cursor].text
    }

    private func error(_ message: String) -> TemplateRuntimeError {
        TemplateRuntimeError(templateName: templateName, line: line, message: message)
    }

    struct Token {
        enum Kind {
            case identifier
            case number
            case string
            case symbol
        }

        let kind: Kind
        let text: String
    }

    enum Tokenizer {
        static let symbols = ["==", "!=", "<=", ">=", "&&", "||", "!", "<", ">", "(", ")", ".", ","]

        static func tokens(of source: String, templateName: String, line: Int) throws -> [Token] {
            var tokens: [Token] = []
            let characters = Array(source)
            var index = 0

            while index < characters.count {
                let character = characters[index]

                if character.isWhitespace {
                    index += 1
                    continue
                }

                if character == "\"" {
                    var text = ""
                    index += 1

                    while index < characters.count, characters[index] != "\"" {
                        if characters[index] == "\\", index + 1 < characters.count {
                            index += 1
                        }

                        text.append(characters[index])
                        index += 1
                    }

                    guard index < characters.count else {
                        throw TemplateRuntimeError(
                            templateName: templateName, line: line,
                            message: "unterminated string literal")
                    }

                    index += 1
                    tokens.append(Token(kind: .string, text: text))
                    continue
                }

                if character.isNumber {
                    var text = ""

                    while index < characters.count,
                          characters[index].isNumber || characters[index] == "." {
                        text.append(characters[index])
                        index += 1
                    }

                    tokens.append(Token(kind: .number, text: text))
                    continue
                }

                if character.isLetter || character == "_" {
                    var text = ""

                    while index < characters.count,
                          characters[index].isLetter || characters[index].isNumber
                            || characters[index] == "_" {
                        text.append(characters[index])
                        index += 1
                    }

                    tokens.append(Token(kind: .identifier, text: text))
                    continue
                }

                let remaining = String(characters[index...])

                guard let symbol = symbols.first(where: { remaining.hasPrefix($0) }) else {
                    throw TemplateRuntimeError(
                        templateName: templateName, line: line,
                        message: "`\(character)` is not supported in a hot-reloaded expression")
                }

                tokens.append(Token(kind: .symbol, text: symbol))
                index += symbol.count
            }

            return tokens
        }
    }
}
