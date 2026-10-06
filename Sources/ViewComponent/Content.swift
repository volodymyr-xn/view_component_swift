/// Caller-supplied markup: the content block, and the payload of content slots.
///
/// Text is escaped on write, markup is trusted, and a builder writes straight
/// into the sink without an intermediate string.
public struct Content {
    private enum Payload {
        case empty
        case text(String)
        case markup(String)
        case builder((inout Sink) -> Void)
    }

    private let payload: Payload

    private init(payload: Payload) {
        self.payload = payload
    }

    public init() {
        payload = .empty
    }

    /// No content at all; renders nothing.
    ///
    /// Computed rather than stored because a `Content` may carry a builder
    /// closure, which makes the type non-`Sendable` and a stored global
    /// illegal under strict concurrency.
    public static var empty: Content { Content() }

    /// Content built from plain text; escaped when written.
    public static func text(_ text: String) -> Content {
        Content(payload: .text(text))
    }

    /// Content built from trusted markup; written verbatim.
    public static func markup(_ markup: SafeString) -> Content {
        Content(payload: .markup(markup.value))
    }

    /// Content built lazily by a closure writing into a string sink.
    ///
    /// A closure cannot be generic, so a builder always writes into the
    /// default `Sink`; its output is handed to the caller's sink in one go.
    public static func builder(_ build: @escaping (inout Sink) -> Void) -> Content {
        Content(payload: .builder(build))
    }

    public var isEmpty: Bool {
        if case .empty = payload {
            return true
        }

        return false
    }

    public func writeInto(_ sink: inout some MarkupSink) {
        switch payload {
        case .empty:
            return
        case .text(let text):
            sink.putEscaped(text)
        case .markup(let markup):
            sink.put(markup)
        case .builder(let build):
            var buffer = Sink()
            build(&buffer)
            sink.put(buffer.markup)
        }
    }
}

extension Content: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension Content: ExpressibleByStringInterpolation {}

public extension Content {
    /// Text, so `component.with(\.heading, "Revenue")` needs no ceremony.
    init(_ text: String) {
        self = .text(text)
    }

    /// Trusted markup.
    init(_ markup: SafeString) {
        self = .markup(markup)
    }
}
