/// Markup that is already escaped, or that is trusted verbatim.
///
/// `emit` writes a `SafeString` straight into the sink, so this is the single
/// opt-out from automatic escaping.
public struct SafeString: Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// Marks `markup` as trusted so it is emitted without escaping.
public func raw(_ markup: String) -> SafeString {
    SafeString(markup)
}

/// ditto
public func raw(_ markup: SafeString) -> SafeString {
    markup
}

/// ditto
public func raw(_ value: some Any) -> SafeString {
    SafeString(String(describing: value))
}

/// The entity `byte` has to be written as, or nil when it can be written as is.
///
/// Public and inlinable because escaping happens twice: `MarkupSink`'s default
/// walks `String` indices, and a sink that owns its bytes — `ByteBufferSink` in
/// the Vapor integration — walks UTF-8 instead. Both have to agree on the five
/// replacements, and a sink in another module scanning a megabyte of markup
/// cannot afford a cross-module call per byte.
@inlinable
public func htmlEntity(for byte: UInt8) -> String? {
    switch byte {
    case UInt8(ascii: "&"): return "&amp;"
    case UInt8(ascii: "<"): return "&lt;"
    case UInt8(ascii: ">"): return "&gt;"
    case UInt8(ascii: "\""): return "&quot;"
    case UInt8(ascii: "'"): return "&#39;"
    default: return nil
    }
}

/// True when `text` holds a character HTML escaping would replace.
func needsHTMLEscaping(_ text: String) -> Bool {
    var text = text

    return text.withUTF8 { bytes in
        for byte in bytes where htmlEntity(for: byte) != nil {
            return true
        }

        return false
    }
}

/// HTML-escapes `input`, returning it untouched when nothing needs escaping.
///
/// The allocating form. Every `<%= %>` goes through `MarkupSink.putEscaped`
/// instead, which writes runs into the caller's buffer and leaves nothing on
/// the heap; this stays for callers holding a string rather than a sink.
public func escapeHTML(_ input: String) -> String {
    guard needsHTMLEscaping(input) else { return input }

    var sink = Sink(reservingCapacity: input.utf8.count + 16)
    sink.putEscaped(input)

    return sink.markup
}
