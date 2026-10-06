import Foundation

/// One named example of a component, the equivalent of a ViewComponent preview.
public struct PreviewCase {
    public let name: String
    public let build: () -> any ViewComponent

    public init(_ name: String, _ build: @escaping () -> any ViewComponent) {
        self.name = name
        self.build = build
    }
}

/// A group of previews for one component.
///
/// Swift has no way to enumerate a module's types, so previews are registered
/// explicitly rather than discovered — the one place this library asks for a
/// line of wiring that the D original inferred.
public protocol ComponentPreview {
    static var previewName: String { get }
    static var previews: [PreviewCase] { get }
}

public extension ComponentPreview {
    static var previewName: String { String(describing: Self.self) }
}

/// Every registered preview, addressable by group and name.
public final class PreviewRegistry: @unchecked Sendable {
    public struct Entry {
        public let group: String
        public let name: String
        public let build: () -> any ViewComponent
    }

    public static let shared = PreviewRegistry()

    private let lock = NSLock()
    private var entries: [Entry] = []

    public static func register(_ preview: (some ComponentPreview).Type) {
        shared.lock.lock()
        defer { shared.lock.unlock() }

        shared.entries.removeAll { $0.group == preview.previewName }
        shared.entries.append(contentsOf: preview.previews.map { previewCase in
            Entry(group: preview.previewName, name: previewCase.name, build: previewCase.build)
        })
    }

    public static func all() -> [Entry] {
        shared.lock.lock()
        defer { shared.lock.unlock() }

        return shared.entries
    }

    /// Renders one preview, or nil when the group or name is unknown.
    public static func render(group: String, name: String) -> String? {
        all().first { $0.group == group && $0.name == name }?.build().render()
    }
}
