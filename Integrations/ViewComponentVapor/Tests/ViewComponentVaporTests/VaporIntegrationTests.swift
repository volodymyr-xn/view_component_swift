import NIOCore
import Testing
import Vapor
import VaporTesting
import ViewComponent
import ViewComponentVapor

@Suite struct VaporIntegrationTests {
    private let notice = SidebarNoticeComponent(
        title: "Q&A <beta>",
        items: ["Billing expires in 4 days", "Degraded performance"])

    @Test func rendersIntoAByteBufferByteForByte() {
        var buffer = notice.renderBuffer()

        #expect(buffer.readString(length: buffer.readableBytes) == notice.render())
    }

    @Test func escapesThroughTheBufferSinkToo() {
        var buffer = notice.renderBuffer()
        let markup = buffer.readString(length: buffer.readableBytes) ?? ""

        #expect(markup.contains("Q&amp;A &lt;beta&gt;"))
        #expect(!markup.contains("<beta>"))
    }

    @Test func buildsAnHTMLResponse() {
        let response = notice.response()

        #expect(response.status == .ok)
        #expect(response.headers.contentType == .html)
        #expect((response.body.string ?? "").contains("<li>Billing expires in 4 days</li>"))
    }

    @Test func keepsAContentTypeTheCallerChose() {
        let response = notice.response(status: .created, headers: ["content-type": "text/plain"])

        #expect(response.status == .created)
        #expect(response.headers.first(name: .contentType) == "text/plain")
    }

    @Test func servesAComponentFromARoute() async throws {
        try await withApp { app in
            app.get("notices") { _ in notice.view() }

            try await app.testing().test(.GET, "notices") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
                #expect(response.body.string.contains("<li>Degraded performance</li>"))
            }
        }
    }
}
