# view-component-swift

ViewComponent-style components for Swift, for the sidebar pattern. A component
is a struct plus a sidecar template in the same directory, compiled together by
a SwiftPM build tool plugin.

```swift
// Sources/App/Components/sidebar_link_component.swift
import ViewComponent

struct SidebarLinkComponent: ViewComponent {
    var label: String
    var href: String
    var state: String

    var cssClass: String { "sidebar__link sidebar__link--\(state)" }
}
```

```erb
<%# Sources/App/Components/sidebar_link_component.html.erb %>
<a class="<%= cssClass %>" href="<%= href %>"><%= label %></a>
```

```swift
SidebarLinkComponent(label: "Overview", href: "/", state: "active").render()
// <a class="sidebar__link sidebar__link--active" href="/">Overview</a>
```

## Install

```swift
dependencies: [
    .package(url: "https://github.com/volodia/view_component_swift.git", from: "0.1.0")
],
targets: [
    .target(
        name: "App",
        dependencies: [.product(name: "ViewComponent", package: "view_component_swift")],
        plugins: [.plugin(name: "ViewComponentTemplates", package: "view_component_swift")]
    )
]
```

**The plugin is required.** It walks the target's source directory, compiles
every `.html.erb` it finds into a Swift extension, and hands the result to the
compiler with the rest of the target. A component with no sidecar does not
conform to `ViewComponent`, so it fails the build rather than rendering
nothing.

## Sidebar components only

This library renders the sidebar pattern, and nothing else. A template's
component must be named `Sidebar…`, and the build fails when it is not:

```
error: view-component: Sources/App/Components/card_component.html.erb:1:
`CardComponent` is not a sidebar component. This library renders the sidebar
pattern only, so a template's component must be named `Sidebar…` — rename it
(`sidebar_card_component.html.erb` → `SidebarCardComponent`), or opt this one
template out with `<%# kind: any %>`.
```

The check is the component's own name, applied at build time, so an
unsupported component never reaches a render. One template can step outside the
rule when it has to:

```erb
<%# kind: any %>
```

Everything below — slots, hooks, hot reload, previews — applies to sidebar
components.

## How it works

The plugin compiles the sidecar into `renderInto(_:)` on your component.
Because the generated code lands *inside* a method of your type, `<%= label %>`
is literally `self.label` — type-checked at compile time, with no context
object, no name lookup and no runtime parsing. Generated files carry
`#sourceLocation` directives, so a typo in a template expression is reported
against the template:

```
Sources/App/Components/sidebar_link_component.html.erb:1:25: error: cannot find 'cssClas' in scope
```

Swift has no compile-time evaluation that can read a file, and macros cannot
touch the filesystem, so the build tool plugin is what D did with `import()`
and a string mixin.

Two consequences worth knowing:

- Template expressions can only reach members that are visible from another
  file in the same module, so `private` members are out. Anything `internal`
  or wider works.
- A `public` component needs `public` witnesses. The plugin looks at how the
  type is declared and matches it; `<%# access: public %>` overrides that if it
  guesses wrong.

## Sidecar layouts

A template is matched to a type by its filename, snake_case to PascalCase
(`sidebar_link_component.html.erb` → `SidebarLinkComponent`). Nothing else
about the directory tree matters, so both layouts work, and a component may
live inside another component's directory:

```
Sources/App/Components/
  sidebar_badge_component.swift            # flat
  sidebar_badge_component.html.erb
  sidebar_group_component/                 # its own sidecar directory
    sidebar_group_component.swift
    sidebar_group_component.html.erb
    sidebar_group_component.css
  sidebar_component/                       # a directory per sub-component
    sidebar_component.swift
    sidebar_component.html.erb
    sidebar_component.css
    sidebar_component.js
    sidebar_section_component/
      sidebar_section_component.swift
      sidebar_section_component.html.erb
    sidebar_link_component/
      sidebar_link_component.swift
      sidebar_link_component.html.erb
    sidebar_footer_component/
      sidebar_footer_component.swift
      sidebar_footer_component.html.erb
```

Sub-components may equally sit loose in their parent's directory — matching is
by filename, so the tree is yours to shape. `Examples/SidebarApp` gives each of
them its own directory, which is what keeps a component's template, class and
assets together as the tree grows.

Names are recovered through an initialism table covering `HTML`, `HTTP`,
`JSON`, `URL`, `API`, `UUID`, `ID`, `IO` and friends. For anything it cannot
spell, name the type in the template:

```erb
<%# component: SidebarPDFLinkComponent %>
```

Every component exposes `templatePath` and `colocatedAssets` — the `.css` and
`.js` files found next to its template — which is what the example's asset
manifest is built from.

Colocated assets are not Swift sources, so list them under `resources:` or
`exclude:` in the target, or SwiftPM warns about unhandled files.

## Template syntax

| Tag | Meaning |
| --- | --- |
| `<% code %>` | Swift statement, emitted verbatim |
| `<%= expr %>` | Swift expression, stringified and HTML-escaped |
| `<%== expr %>` | Swift expression, emitted **unescaped** |
| `<%# text %>` | comment, discarded |
| `<%%` | a literal `<%` |
| `<%-` … `-%>` | trim the preceding indentation / the following newline |

A line holding nothing but a `<% %>` or `<%# %>` tag is dropped from the output
along with its newline, so control flow needs no `<%-` markers:

```erb
<ul class="sidebar__links">
  <% for link in links { %>
  <li><%= link %></li>
  <% } %>
</ul>
```

`<%-` and `-%>` are still there for a tag that sits *inline* among markup, and
`<%# whitespace: keep %>` turns the automatic pass off for a whole template —
which is what a `<pre>` block wants.

Expressions are full Swift — anything in scope in a method of your component,
including its `internal` members. In scope on top of that:

- `render(value)` — renders a component, an optional, or an array of them
- `raw(value)` — marks a value as trusted markup

Escaping is automatic and covers `& < > " '`. `<%= section %>` renders a nested
component; `<%= someArray %>` of components renders each in order.

The one limitation: a tag body may not contain the literal `%>`, including
inside a Swift string. Move such an expression onto the component.

## Rendering components inside a template

Two equivalent forms — `render(...)` as a statement, or `<%= ... %>` as an
expression. Both write into the *same* sink as the enclosing component, so a
whole tree costs one buffer, not one string per node. A sink is anything
conforming to `MarkupSink`; `render()` uses the string-backed `Sink`, and a
server can pass its own — see below.

```erb
<%# a single child held in a property %>
<% render(footer) %>
<%= footer %>

<%# an array of children — rendered in order %>
<% render(links) %>
<%= links %>

<%# constructed inline %>
<% render(SidebarLinkComponent(label: "Overview", href: "/", state: "active")) %>

<%# conditionally, and in a loop %>
<% if let footer { %>
<% render(footer) %>
<% } %>

<% for section in sections { %>
<% render(section) %>
<% } %>
```

Children need no import ceremony beyond the usual: the template body is
compiled into your module, so any type the module can see, it can render.

A parent pushes state down in `beforeRender`, which runs before the component
renders and before any child does:

```swift
mutating func beforeRender() {
    for index in sections.indices {
        sections[index].currentPath = currentPath
    }
}
```

## Slots

Slots are ordinary properties. `renders_one` is an optional, `renders_many` is
an array, and the markup slots are `Content`:

```swift
struct SidebarComponent: ViewComponent {
    var brand: Content = .empty                      // one markup slot
    var notices: [Content] = []                      // many markup slots
    var sections: [SidebarSectionComponent] = []     // many component slots
    var footer: SidebarFooterComponent?              // one component slot
    var content: Content = .empty                    // the content block
}
```

`with(_:_:)` and `adding(_:_:)` set them without a setter per slot, and return
a copy — components are values:

```swift
SidebarComponent(currentPath: "/projects")
    .with(\.brand, .markup(raw("<strong>Acme</strong>&nbsp;Console")))
    .adding(\.notices, "Billing details expire in 4 days")
    .adding(\.sections, workspace, reports)
    .with(\.footer, SidebarFooterComponent(userName: "Ada Lovelace", role: "Owner"))
    .render()
```

`Content` holds text (escaped on write), `raw(...)` markup (written verbatim),
or a builder closure that writes straight into the sink. `content` is a
convention rather than a protocol requirement: declare it when a component
takes a content block, leave it out when it does not.

Templates read a slot the way any other property is read, and ask about it with
plain Swift: `!brand.isEmpty`, `!sections.isEmpty`, `if let footer`.

## Rendering hooks

Override `beforeRender()` to derive state, and `shouldRender()` to suppress the
component entirely (the equivalent of ViewComponent's `render?` — an empty
sidebar section renders nothing at all). `beforeRender` is `mutating` and runs
on a copy, so derived state never leaks back into the value the caller is
holding.

## Hot reload

The compiled backend is the only one that runs by default. Switch on hot reload
and an *edited* sidecar is read from disk and interpreted instead — a template
whose bytes still match the one it was built from keeps rendering through
generated code, so a debug build and a release build differ only where you just
typed:

```swift
TemplateHotReload.shared.enable(searchPaths: ["Sources/App/Components"])
```

or set `VIEW_COMPONENT_HOT_RELOAD=1`. `searchPaths` is optional; without it the
absolute path the template was compiled from is used.

The interpreter deliberately covers less than the compiler:

- member paths, zero-argument calls, `isEmpty`, `count`
- string, integer and boolean literals, `!`, `&&`, `||`, `== != < <= > >=`
- `if` / `else if` / `else`, `if let`, `for x in xs`, `render(x)`, `raw(x)`

Computed properties still evaluate as real Swift: the plugin generates a
`templateBinding(_:)` for every member the template names, so `cssClass` in an
edited template is the same `cssClass` the compiler would have called. Stored
properties the compiled template never mentioned are reached by reflection.
Naming a *computed* member the compiled template never used needs a rebuild —
so does adding the member, so this rarely bites.

Anything outside that subset renders as a visible error block in place, rather
than as silently stale markup.

## Vapor

`Integrations/ViewComponentVapor` renders a component straight into the
`ByteBuffer` the response is sent from — no intermediate `String`:

```swift
import ViewComponentVapor

app.get("nav") { _ in
    buildSidebar(currentPath: "/projects").view()
}

// or, when the route sets its own status and headers
app.post("notices") { _ in
    SidebarNoticeComponent(title: "Saved").response(status: .created)
}
```

`view()` returns a Vapor `View`, which is already response-encodable;
`response(status:headers:)` and `Response(component:)` build a full response and
default `Content-Type` to HTML unless the caller chose one. `ByteBufferSink` is
the `MarkupSink` behind both, and is usable on its own wherever NIO buffers are.

It is a separate package so that a library everyone imports does not pull
Vapor's dependency graph into every consumer's resolution. In a monorepo, point
at it directly:

```swift
.package(path: "path/to/view_component_swift/Integrations/ViewComponentVapor")
```

## Previews and tests

```swift
struct SidebarLinkComponentPreview: ComponentPreview {
    static var previews: [PreviewCase] {
        [
            PreviewCase("plain") {
                SidebarLinkComponent(label: "Overview", href: "/", icon: "◱")
            },
            PreviewCase("with badge") {
                SidebarLinkComponent(label: "Projects", href: "/projects", icon: "▤")
                    .withBadgeCount(3)
            },
        ]
    }
}

PreviewRegistry.register(SidebarLinkComponentPreview.self)
PreviewRegistry.render(group: "SidebarLinkComponentPreview", name: "plain")
```

Previews are registered rather than discovered — Swift cannot enumerate the
types in a module the way D's compile-time reflection can, and this is the one
line of wiring the port asks for that the original inferred.

`ViewComponentTesting` provides `assertIncludes`, `assertExcludes`,
`assertRendersEqual`, `assertRendersEqualNormalized`, `assertHasElement` and
`hasElement`. They throw `ComponentAssertionFailure`, which any test framework
reports:

```swift
@Test func rendersTheLabel() throws {
    try assertIncludes(SidebarLinkComponent(label: "Overview", state: "active"), "Overview")
}
```

CSS selector matching is not implemented — `assertHasElement` matches a tag
name plus attribute substrings.

## Benchmark

`../benchmark/` — shared with the other ports in the surrounding
`view_component_implementations` checkout — renders a dashboard of **15
component types nested five levels deep** in four languages, and checks that
every one of them emits byte-identical normalised markup before reporting a
timing. This library appears twice: the view layer on its own
(`benchmark/swift`, components plus an in-process harness) and inside a full
Vapor application reading SQLite through SQLiteNIO and through Fluent
(`benchmark/apps/vapor-app`).

```sh
../benchmark/run
```

Components live in a library target the Vapor app depends on, so both rows
render the same tree from the same source. See `../benchmark/README.md`.

## Development

```sh
swift test                       # library, syntax and hot-reload suites
cd Examples/SidebarApp && swift run
cd Integrations/ViewComponentVapor && swift test
```

`Examples/SidebarApp` is the reference for anything this README only sketches:
a three-level tree (`SidebarComponent` → `SidebarSectionComponent` →
`SidebarLinkComponent`) plus a footer, in one sidecar directory with colocated
CSS and JS, using every slot shape and the content block, `beforeRender` to
push the current path down the tree, `shouldRender` to drop an empty section,
and an asset manifest built from what the plugin found.

Requires Swift 6.1 or newer.

## Licence

MIT.
