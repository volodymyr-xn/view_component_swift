import Testing
import ViewComponent

struct SidebarLinkComponentPreview: ComponentPreview {
    static var previews: [PreviewCase] {
        [
            PreviewCase("active") { SidebarLinkComponent(label: "Overview", state: "active") },
            PreviewCase("muted") { SidebarLinkComponent(label: "Archived", state: "muted") },
        ]
    }
}

@Suite(.serialized) struct PreviewTests {
    @Test func registersEveryCaseUnderTheGroupName() {
        PreviewRegistry.register(SidebarLinkComponentPreview.self)

        let names = PreviewRegistry.all()
            .filter { $0.group == "SidebarLinkComponentPreview" }
            .map(\.name)

        #expect(names == ["active", "muted"])
    }

    @Test func rendersOneByGroupAndName() {
        PreviewRegistry.register(SidebarLinkComponentPreview.self)

        let markup = PreviewRegistry.render(group: "SidebarLinkComponentPreview", name: "muted")

        #expect(markup?.contains("sidebar__link--muted") == true)
        #expect(PreviewRegistry.render(group: "SidebarLinkComponentPreview", name: "nope") == nil)
    }

    @Test func reregisteringReplacesTheGroup() {
        PreviewRegistry.register(SidebarLinkComponentPreview.self)
        PreviewRegistry.register(SidebarLinkComponentPreview.self)

        #expect(PreviewRegistry.all().filter { $0.group == "SidebarLinkComponentPreview" }.count == 2)
    }
}
