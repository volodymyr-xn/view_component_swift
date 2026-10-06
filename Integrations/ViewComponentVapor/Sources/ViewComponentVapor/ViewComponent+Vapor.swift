import NIOCore
import Vapor
import ViewComponent

public extension ViewComponent {
    /// Renders into a fresh `ByteBuffer`, with no `String` in between.
    func renderBuffer(
        allocator: ByteBufferAllocator = ByteBufferAllocator(),
        reservingCapacity capacity: Int = 1024
    ) -> ByteBuffer {
        var sink = ByteBufferSink(allocator: allocator, reservingCapacity: capacity)
        render(into: &sink)

        return sink.buffer
    }

    /// The component as a Vapor `View`, which is already response-encodable:
    ///
    ///   app.get("dashboard") { request in
    ///       DashboardComponent(month: "August").view()
    ///   }
    func view() -> View {
        View(data: renderBuffer())
    }

    /// The component as a full response, for a route that sets its own status
    /// or headers.
    func response(
        status: HTTPResponseStatus = .ok,
        headers: HTTPHeaders = [:]
    ) -> Response {
        Response(status: status, headers: headers, component: self)
    }
}

public extension Response {
    /// A response whose body is the rendered component. `Content-Type` is set
    /// to HTML unless the caller already chose one.
    convenience init(
        status: HTTPResponseStatus = .ok,
        headers: HTTPHeaders = [:],
        component: some ViewComponent
    ) {
        var responseHeaders = headers

        if responseHeaders.contentType == nil {
            responseHeaders.contentType = .html
        }

        self.init(
            status: status,
            headers: responseHeaders,
            body: .init(buffer: component.renderBuffer())
        )
    }
}
