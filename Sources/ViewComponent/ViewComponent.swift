/// Base protocol for all components.
///
/// The static members and `renderInto` are supplied by the generated sidecar
/// extension, so a component without a template fails to conform. Everything a
/// template reads is an ordinary property of the conforming type: the compiled
/// template body lands inside a method of the component, which is what makes
/// `<%= label %>` literally `self.label`.
public protocol ViewComponent: TemplateEmittable {
    /// Path of the sidecar, relative to the target's source directory.
    static var templatePath: String { get }
    /// Absolute path the template was compiled from; used by hot reload.
    static var templateSourcePath: String { get }
    /// Hash of the compiled template source, used to detect an edited sidecar.
    static var templateSourceHash: UInt64 { get }
    /// `.css` / `.js` files sitting next to the template, found at build time.
    static var colocatedAssets: [String] { get }

    /// Generated from the sidecar template.
    func renderInto(_ sink: inout some MarkupSink)

    /// Generated lookup of the members the template names, for hot reload.
    func templateBinding(_ name: String) -> TemplateValue?

    /// Hook invoked before every render; override to derive state.
    mutating func beforeRender()

    /// Return false to suppress the component entirely, like `render?`.
    func shouldRender() -> Bool
}

public extension ViewComponent {
    static var templateSourcePath: String { "" }

    static var colocatedAssets: [String] { [] }

    func templateBinding(_ name: String) -> TemplateValue? { nil }

    mutating func beforeRender() {}

    func shouldRender() -> Bool { true }

    /// Renders standalone and returns the markup.
    ///
    /// `capacity` is worth passing whenever the size of the output is roughly
    /// known: the buffer starts at 512 bytes and doubles, so a page that ends
    /// up megabytes long is copied through every intermediate size on the way.
    func render(reservingCapacity capacity: Int = 512) -> String {
        var sink = Sink(reservingCapacity: capacity)
        render(into: &sink)

        return sink.markup
    }

    /// Renders into an existing sink, running the render hooks.
    func render(into sink: inout some MarkupSink) {
        var component = self
        component.beforeRender()

        guard component.shouldRender() else { return }

        if let template = TemplateHotReload.shared.editedTemplate(for: Self.self) {
            template.render(component, into: &sink)

            return
        }

        component.renderInto(&sink)
    }

    func emitInto(_ sink: inout some MarkupSink) {
        render(into: &sink)
    }

    /// Returns a copy with one property replaced, the value-type equivalent of
    /// ViewComponent's `with_` slot setters:
    ///
    ///   CardComponent().with(\.heading, "Revenue")
    func with<Value>(_ keyPath: WritableKeyPath<Self, Value>, _ value: Value) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value

        return copy
    }

    /// Returns a copy with values appended to a collection slot:
    ///
    ///   CardComponent().adding(\.actions, exportButton, deleteButton)
    func adding<Value>(_ keyPath: WritableKeyPath<Self, [Value]>, _ values: Value...) -> Self {
        var copy = self
        copy[keyPath: keyPath] += values

        return copy
    }
}
