/// Build-time settings a template carries in its own comments.
///
///   `<%# component: HTMLBlockComponent %>`  name the type explicitly
///   `<%# access: public %>`                 force the generated access level
///   `<%# whitespace: keep %>`               do not trim standalone tag lines
///   `<%# kind: any %>`                      exempt from the sidebar-only rule
public struct TemplateDirectives: Equatable, Sendable {
    public var componentType: String?
    public var accessLevel: String?
    public var whitespace: String?
    public var kind: String?

    public var trimsStandaloneTags: Bool { whitespace != "keep" }

    public var enforcesSidebarKind: Bool { kind != "any" }

    public init(
        componentType: String? = nil,
        accessLevel: String? = nil,
        whitespace: String? = nil,
        kind: String? = nil
    ) {
        self.componentType = componentType
        self.accessLevel = accessLevel
        self.whitespace = whitespace
        self.kind = kind
    }

    public static func scan(_ source: String) -> TemplateDirectives {
        var directives = TemplateDirectives()
        let characters = Array(source)
        var index = 0

        while index + 2 < characters.count {
            guard characters[index] == "<", characters[index + 1] == "%",
                  characters[index + 2] == "#" else {
                index += 1
                continue
            }

            var end = index + 3

            while end + 1 < characters.count,
                  !(characters[end] == "%" && characters[end + 1] == ">") {
                end += 1
            }

            let body = String(characters[(index + 3)..<min(end, characters.count)]).trimmed

            if let separator = body.firstIndex(of: ":") {
                let key = String(body[body.startIndex..<separator]).trimmed
                let value = String(body[body.index(after: separator)...]).trimmed

                switch key {
                case "component":
                    directives.componentType = value
                case "access":
                    directives.accessLevel = value
                case "whitespace":
                    directives.whitespace = value
                case "kind":
                    directives.kind = value
                default:
                    break
                }
            }

            index = end + 2
        }

        return directives
    }
}
