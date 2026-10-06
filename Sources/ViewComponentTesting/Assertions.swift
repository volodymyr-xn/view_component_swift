import Foundation
import ViewComponent

/// A failed component assertion, thrown so any test framework reports it.
public struct ComponentAssertionFailure: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

/// The markup a component renders, hooks and all.
public func renderedMarkup(of component: some ViewComponent) -> String {
    component.render()
}

public func assertIncludes(
    _ component: some ViewComponent,
    _ needle: String
) throws {
    let markup = component.render()

    guard !markup.contains(needle) else { return }

    throw ComponentAssertionFailure(
        "expected the render to include \(quoted(needle)), got:\n\(markup)")
}

public func assertExcludes(
    _ component: some ViewComponent,
    _ needle: String
) throws {
    let markup = component.render()

    guard markup.contains(needle) else { return }

    throw ComponentAssertionFailure(
        "expected the render to exclude \(quoted(needle)), got:\n\(markup)")
}

public func assertRendersEqual(
    _ component: some ViewComponent,
    _ expected: String
) throws {
    let markup = component.render()

    guard markup != expected else { return }

    throw ComponentAssertionFailure("expected:\n\(expected)\ngot:\n\(markup)")
}

/// Compares renders with runs of whitespace collapsed and inter-tag whitespace
/// dropped, so template indentation is not part of the contract.
public func assertRendersEqualNormalized(
    _ component: some ViewComponent,
    _ expected: String
) throws {
    let markup = normalizedMarkup(component.render())
    let normalizedExpectation = normalizedMarkup(expected)

    guard markup != normalizedExpectation else { return }

    throw ComponentAssertionFailure("expected:\n\(normalizedExpectation)\ngot:\n\(markup)")
}

public func assertHasElement(
    _ component: some ViewComponent,
    tag: String,
    attributes: [String: String] = [:]
) throws {
    let markup = component.render()

    guard !hasElement(markup, tag: tag, attributes: attributes) else { return }

    throw ComponentAssertionFailure(
        "expected a `<\(tag)>` with \(attributes), got:\n\(markup)")
}

/// Whether `markup` holds an opening tag named `tag` carrying every attribute.
///
/// CSS selectors are not implemented: this matches a tag name plus attribute
/// substrings, which covers what component tests actually assert.
public func hasElement(_ markup: String, tag: String, attributes: [String: String] = [:]) -> Bool {
    var searchRange = markup.startIndex..<markup.endIndex

    while let opening = markup.range(of: "<\(tag)", range: searchRange) {
        searchRange = opening.upperBound..<markup.endIndex

        let boundary = markup[opening.upperBound...].first

        guard boundary == nil || boundary == ">" || boundary == " " || boundary == "\n"
            || boundary == "/" else {
            continue
        }

        guard let closing = markup.range(of: ">", range: searchRange) else { return false }

        let openingTag = String(markup[opening.lowerBound..<closing.upperBound])
        let matchesAll = attributes.allSatisfy { name, value in
            openingTag.contains("\(name)=\"\(value)\"")
        }

        if matchesAll {
            return true
        }
    }

    return false
}

public func normalizedMarkup(_ markup: String) -> String {
    let collapsed = markup
        .replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression)
        .replacingOccurrences(
            of: ">\\s+<", with: "><", options: .regularExpression)

    return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func quoted(_ text: String) -> String {
    "`\(text)`"
}
