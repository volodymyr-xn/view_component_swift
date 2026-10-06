/// A value the hot-reload runtime can read out of a component.
///
/// The generated `templateBinding(_:)` produces these from real Swift
/// expressions, so an edited template evaluates computed properties with the
/// same semantics the compiled backend would have given them. Reflection fills
/// in stored properties the compiled template never mentioned.
public enum TemplateValue {
    case none
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case markup(SafeString)
    case content(Content)
    case component(any ViewComponent)
    case list([TemplateValue])

    public init(reflecting value: Any) {
        switch value {
        case let text as String:
            self = .string(text)
        case let markup as SafeString:
            self = .markup(markup)
        case let content as Content:
            self = .content(content)
        case let flag as Bool:
            self = .bool(flag)
        case let number as Int:
            self = .int(number)
        case let number as Double:
            self = .double(number)
        case let component as any ViewComponent:
            self = .component(component)
        default:
            self = TemplateValue.reflectingCompound(value)
        }
    }

    private static func reflectingCompound(_ value: Any) -> TemplateValue {
        let mirror = Mirror(reflecting: value)

        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return .none }

            return TemplateValue(reflecting: wrapped)
        }

        if mirror.displayStyle == .collection {
            return .list(mirror.children.map { TemplateValue(reflecting: $0.value) })
        }

        return .string(String(describing: value))
    }

    /// Whether the value counts as true in a template condition.
    public var isTruthy: Bool {
        switch self {
        case .none: false
        case .bool(let flag): flag
        case .int(let number): number != 0
        case .double(let number): number != 0
        case .string(let text): !text.isEmpty
        case .markup(let markup): !markup.value.isEmpty
        case .content(let content): !content.isEmpty
        case .component: true
        case .list(let values): !values.isEmpty
        }
    }

    /// The member `name` of this value, or nil when it has none.
    public func member(_ name: String) -> TemplateValue? {
        switch self {
        case .string(let text):
            return TemplateValue.collectionMember(name, isEmpty: text.isEmpty, count: text.count)
        case .markup(let markup):
            return TemplateValue.collectionMember(
                name, isEmpty: markup.value.isEmpty, count: markup.value.count)
        case .content(let content):
            return name == "isEmpty" ? .bool(content.isEmpty) : nil
        case .list(let values):
            return TemplateValue.collectionMember(name, isEmpty: values.isEmpty, count: values.count)
        case .component(let component):
            return component.templateBinding(name) ?? TemplateValue.reflectedMember(name, of: component)
        case .none, .bool, .int, .double:
            return nil
        }
    }

    private static func collectionMember(_ name: String, isEmpty: Bool, count: Int) -> TemplateValue? {
        switch name {
        case "isEmpty": .bool(isEmpty)
        case "count": .int(count)
        default: nil
        }
    }

    /// A stored property read straight off the component, for names the
    /// compiled template never referenced.
    public static func reflectedMember(_ name: String, of subject: Any) -> TemplateValue? {
        for child in Mirror(reflecting: subject).children where child.label == name {
            return TemplateValue(reflecting: child.value)
        }

        return nil
    }
}

extension TemplateValue: TemplateEmittable {
    public func emitInto(_ sink: inout some MarkupSink) {
        switch self {
        case .none:
            return
        case .bool(let flag):
            sink.put(flag.description)
        case .int(let number):
            sink.put(number.description)
        case .double(let number):
            sink.put(number.description)
        case .string(let text):
            sink.putEscaped(text)
        case .markup(let markup):
            sink.put(markup.value)
        case .content(let content):
            content.writeInto(&sink)
        case .component(let component):
            component.emitInto(&sink)
        case .list(let values):
            for value in values {
                value.emitInto(&sink)
            }
        }
    }

    /// The unescaped text of a value, used by `<%== %>` and by comparisons.
    public var text: String {
        switch self {
        case .none: ""
        case .bool(let flag): flag.description
        case .int(let number): number.description
        case .double(let number): number.description
        case .string(let text): text
        case .markup(let markup): markup.value
        case .content: ""
        case .component: ""
        case .list: ""
        }
    }
}
