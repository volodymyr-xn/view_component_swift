/// Anything a `<%= %>` tag can write into the sink.
///
/// Conformance is what decides escaping: strings escape, `SafeString` and
/// components do not, and everything else falls through to a stringified,
/// escaped description.
public protocol TemplateEmittable {
    func emitInto(_ sink: inout some MarkupSink)
}

extension String: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.putEscaped(self)
    }
}

extension Substring: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.putEscaped(String(self))
    }
}

extension SafeString: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.put(value)
    }
}

extension Content: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        writeInto(&sink)
    }
}

extension Int: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.put(description)
    }
}

extension Double: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.put(description)
    }
}

extension Bool: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        sink.put(description)
    }
}

extension Optional: TemplateEmittable where Wrapped: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        self?.emitInto(&sink)
    }
}

extension Array: TemplateEmittable where Element: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        for element in self {
            element.emitInto(&sink)
        }
    }
}

/// Writes one `<%= %>` expression into the sink.
public func emit(_ sink: inout some MarkupSink, _ value: some TemplateEmittable) {
    value.emitInto(&sink)
}

/// ditto — an array of existential children. Unlike a lone `any ViewComponent`,
/// which the compiler opens implicitly into `some TemplateEmittable`, an array
/// of them conforms to nothing and needs its own overload.
public func emit(_ sink: inout some MarkupSink, _ value: [any ViewComponent]) {
    for component in value {
        component.emitInto(&sink)
    }
}

/// ditto — anything else is stringified and escaped.
public func emit(_ sink: inout some MarkupSink, _ value: some Any) {
    sink.putEscaped(String(describing: value))
}
