import Foundation
import ViewComponentTemplateSyntax

/// The development loop: render an edited sidecar without rebuilding.
///
/// Off unless it is switched on, and even then it only takes over for a
/// template whose bytes differ from the one the component was compiled with —
/// an untouched template still renders through the generated code, so debug
/// and release builds agree on everything that was not just edited.
///
///   TemplateHotReload.shared.enable(searchPaths: ["Sources/App/Components"])
///
/// or set `VIEW_COMPONENT_HOT_RELOAD=1` in the environment.
public final class TemplateHotReload: @unchecked Sendable {
    public static let shared = TemplateHotReload()

    private struct CacheEntry {
        let modifiedAt: Date
        let sourceHash: UInt64
        let template: RuntimeTemplate?
    }

    private let lock = NSLock()
    private var searchPaths: [String] = []
    private var cache: [String: CacheEntry] = [:]

    /// Read without the lock on every render: a stale `false` costs nothing,
    /// and paying for a lock on the hot path of every component would not be.
    private var isEnabled = false

    private init() {
        if ProcessInfo.processInfo.environment["VIEW_COMPONENT_HOT_RELOAD"] == "1" {
            isEnabled = true
        }
    }

    /// Switches hot reload on. `searchPaths` are consulted when a component's
    /// build-time template path no longer exists — after moving the checkout,
    /// or when rendering from a different working directory.
    public func enable(searchPaths: [String] = []) {
        lock.lock()
        defer { lock.unlock() }

        self.searchPaths = searchPaths
        isEnabled = true
    }

    public func disable() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        isEnabled = false
    }

    /// Drops every cached template, so the next render re-reads from disk.
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
    }

    /// The on-disk template for `type`, but only when it differs from the one
    /// compiled into the binary.
    func editedTemplate<Component: ViewComponent>(for type: Component.Type) -> RuntimeTemplate? {
        guard isEnabled else { return nil }

        lock.lock()
        defer { lock.unlock() }

        guard let path = resolvePath(for: type) else { return nil }

        let modifiedAt = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate])
            .flatMap { $0 as? Date } ?? Date.distantPast

        if let cached = cache[path], cached.modifiedAt == modifiedAt {
            return cached.sourceHash == Component.templateSourceHash ? nil : cached.template
        }

        guard let source = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }

        let sourceHash = TemplateSourceHash.of(source)

        guard sourceHash != Component.templateSourceHash else {
            cache[path] = CacheEntry(modifiedAt: modifiedAt, sourceHash: sourceHash, template: nil)

            return nil
        }

        let template: RuntimeTemplate?

        do {
            template = try RuntimeTemplate(
                source: source, templateName: Component.templatePath)
        } catch {
            template = FailedTemplate.make(message: "\(error)", path: Component.templatePath)
        }

        cache[path] = CacheEntry(
            modifiedAt: modifiedAt, sourceHash: sourceHash, template: template)

        return template
    }

    /// Configured search paths win over the path the template was compiled
    /// from: passing one is an explicit instruction about where templates live
    /// now, which is the whole point when the checkout moved.
    private func resolvePath<Component: ViewComponent>(for type: Component.Type) -> String? {
        let fileManager = FileManager.default

        for searchPath in searchPaths {
            let candidate = (searchPath as NSString)
                .appendingPathComponent(Component.templatePath)

            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }

        let compiledPath = Component.templateSourcePath

        guard !compiledPath.isEmpty, fileManager.fileExists(atPath: compiledPath) else {
            return nil
        }

        return compiledPath
    }
}

/// A template that only ever renders its own parse error.
private enum FailedTemplate {
    static func make(message: String, path: String) -> RuntimeTemplate? {
        let escapedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "<%", with: "&lt;%")

        return try? RuntimeTemplate(
            source: RuntimeTemplate.errorMarkup(escapedMessage), templateName: path)
    }
}
