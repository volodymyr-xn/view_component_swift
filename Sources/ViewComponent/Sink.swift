/// Somewhere markup can be written to.
///
/// Rendering is generic over this rather than tied to a string buffer, so a
/// server can render a whole component tree straight into the buffer it is
/// about to hand the network — see `ViewComponentVapor`.
public protocol MarkupSink {
    mutating func put(_ text: String)
    mutating func put(_ text: Substring)
    mutating func putEscaped(_ text: String)
}

public extension MarkupSink {
    mutating func put(_ text: Substring) {
        put(String(text))
    }

    /// Writes `text` with HTML's five reserved characters replaced.
    ///
    /// A protocol requirement rather than a free function so a sink that owns
    /// its bytes can escape straight into them. The default walks the input's
    /// UTF-8 and hands over whole unescaped runs, which allocates nothing: the
    /// alternative — building an escaped `String` and appending that — costs a
    /// throwaway allocation and a second copy for every `<%= %>` on the page.
    ///
    /// The split points are always ASCII, so they are scalar boundaries and the
    /// slices are exact.
    mutating func putEscaped(_ text: String) {
        let utf8 = text.utf8
        var runStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            guard let entity = htmlEntity(for: utf8[index]) else {
                index = utf8.index(after: index)
                continue
            }

            if runStart < index {
                put(Substring(utf8[runStart ..< index]))
            }

            put(entity)
            index = utf8.index(after: index)
            runStart = index
        }

        if runStart == text.startIndex {
            put(text)
        } else if runStart < text.endIndex {
            put(Substring(utf8[runStart ..< text.endIndex]))
        }
    }
}

/// The default sink: one string buffer for a whole component tree.
///
/// Nesting, slots and content blocks all append to the caller's sink, so a
/// tree costs one buffer rather than one string per node.
public struct Sink: MarkupSink {
    public private(set) var markup: String

    public init(reservingCapacity capacity: Int = 512) {
        markup = ""
        markup.reserveCapacity(capacity)
    }

    public mutating func put(_ text: String) {
        markup += text
    }

    public mutating func put(_ text: Substring) {
        markup += text
    }
}
