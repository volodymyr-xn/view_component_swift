import Foundation

/// Collects the component members a template names.
///
/// The generated `templateBinding(_:)` turns each one into a real Swift
/// expression, which is what lets the hot-reload runtime evaluate an edited
/// template against computed properties it could never reach by reflection.
/// Harvesting is deliberately conservative: a name that is bound inside the
/// template, or that looks like a type, is left out rather than risk emitting
/// a member that does not exist.
public enum BindingHarvester {
    /// A member the template reads, in the form the generated switch calls it.
    public struct Binding: Equatable, Sendable {
        public let name: String
        public let isCall: Bool
        /// Template line the name was first read on, so a member that does not
        /// exist is reported against the template rather than generated code.
        public let line: Int

        public var callExpression: String { isCall ? "\(name)()" : name }
    }

    public static func bindings(in nodes: [TemplateNode]) -> [Binding] {
        var localNames = Set<String>()
        var order: [String] = []
        var callNames = Set<String>()
        var lines: [String: Int] = [:]

        for node in nodes {
            guard case .statement(let code, _) = node else { continue }

            localNames.formUnion(locallyBoundNames(in: code))
        }

        for node in nodes {
            let expression: String
            let line: Int

            switch node {
            case .text:
                continue
            case .escapedOutput(let code, let nodeLine), .rawOutput(let code, let nodeLine):
                expression = code
                line = nodeLine
            case .statement(let code, let nodeLine):
                expression = code
                line = nodeLine
            }

            for reference in references(in: expression) {
                guard !localNames.contains(reference.name) else { continue }

                if reference.isCall {
                    callNames.insert(reference.name)
                }

                if !order.contains(reference.name) {
                    order.append(reference.name)
                    lines[reference.name] = line
                }
            }
        }

        return order.map {
            Binding(name: $0, isCall: callNames.contains($0), line: lines[$0] ?? 1)
        }
    }

    private static let reservedNames: Set<String> = [
        "true", "false", "nil", "self", "super", "let", "var", "if", "else",
        "for", "in", "while", "repeat", "return", "guard", "switch", "case",
        "default", "break", "continue", "where", "is", "as", "try", "throw",
        "do", "catch", "func", "init", "some", "any", "raw", "render", "emit",
        "print", "min", "max", "abs", "zip",
    ]

    private struct Reference {
        let name: String
        let isCall: Bool
    }

    private static func references(in expression: String) -> [Reference] {
        var references: [Reference] = []
        let characters = Array(expression)
        var index = 0
        var insideString = false

        while index < characters.count {
            let character = characters[index]

            if insideString {
                if character == "\\" {
                    index += 2
                    continue
                }

                if character == "\"" {
                    insideString = false
                }

                index += 1
                continue
            }

            if character == "\"" {
                insideString = true
                index += 1
                continue
            }

            guard character.isIdentifierHead else {
                index += 1
                continue
            }

            var end = index

            while end < characters.count, characters[end].isIdentifierBody {
                end += 1
            }

            let name = String(characters[index..<end])
            let previous = index > 0 ? characters[index - 1] : " "
            var next = end

            while next < characters.count, characters[next] == " " {
                next += 1
            }

            let isCall = next < characters.count && characters[next] == "("
            let isMember = previous == "." || previous == "\\"
            let looksLikeType = name.first?.isUppercase ?? true

            if !isMember, !looksLikeType, !reservedNames.contains(name) {
                references.append(Reference(name: name, isCall: isCall))
            }

            index = end
        }

        return references
    }

    /// Names introduced by the template itself, which are not members.
    ///
    /// `let total = links.count` binds `total`; the `if let footer` shorthand
    /// binds nothing new, so `footer` stays a member reference.
    private static func locallyBoundNames(in code: String) -> Set<String> {
        var names = Set<String>()
        let tokens = tokenize(code)

        for (index, token) in tokens.enumerated() {
            switch token {
            case "let", "var":
                guard index + 2 < tokens.count, tokens[index + 2] == "=" else { continue }

                names.insert(tokens[index + 1])
            case "for":
                for candidate in tokens[(index + 1)...] {
                    if candidate == "in" { break }

                    names.insert(candidate)
                }
            default:
                break
            }
        }

        return names
    }

    /// Identifiers plus single-character symbols, so `let x =` is
    /// distinguishable from `let x` without a full Swift parser.
    private static func tokenize(_ code: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for character in code {
            if character.isIdentifierBody {
                current.append(character)
                continue
            }

            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }

            if !character.isWhitespace {
                tokens.append(String(character))
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

}

extension Character {
    var isIdentifierHead: Bool {
        isLetter || self == "_"
    }

    var isIdentifierBody: Bool {
        isLetter || isNumber || self == "_"
    }
}
