/// The library renders the sidebar pattern, and only the sidebar pattern.
///
/// A component's own name is the check: a template compiles when it belongs to
/// a `Sidebar…` component, and fails the build otherwise, so an unsupported
/// component never reaches a render. A template that has to sit outside the
/// pattern says so for itself with `<%# kind: any %>`.
public enum SidebarComponentRule {
    public static let requiredPrefix = "Sidebar"

    public static func isSidebarComponent(_ typeName: String) -> Bool {
        typeName.hasPrefix(requiredPrefix)
    }

    /// Throws unless `typeName` is a sidebar component, or the template opted
    /// out of the rule.
    public static func validate(
        typeName: String,
        directives: TemplateDirectives,
        templateName: String
    ) throws {
        guard directives.enforcesSidebarKind, !isSidebarComponent(typeName) else { return }

        throw TemplateSyntaxError(
            templateName: templateName,
            line: 1,
            message: """
            `\(typeName)` is not a sidebar component. This library renders the \
            sidebar pattern only, so a template's component must be named \
            `\(requiredPrefix)…` — rename it (`sidebar_card_component.html.erb` \
            → `SidebarCardComponent`), or opt this one template out with \
            `<%# kind: any %>`.
            """
        )
    }
}
