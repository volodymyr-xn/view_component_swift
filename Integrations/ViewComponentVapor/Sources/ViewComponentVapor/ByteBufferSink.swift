import NIOCore
import ViewComponent

/// A sink that writes straight into the buffer the response will be sent from.
///
/// Rendering a tree through this never builds an intermediate `String`: every
/// literal and every escaped expression is appended as UTF-8 to the buffer
/// Vapor hands to the network.
public struct ByteBufferSink: MarkupSink {
    public private(set) var buffer: ByteBuffer

    public init(buffer: ByteBuffer) {
        self.buffer = buffer
    }

    public init(
        allocator: ByteBufferAllocator = ByteBufferAllocator(),
        reservingCapacity capacity: Int = 1024
    ) {
        buffer = allocator.buffer(capacity: capacity)
    }

    public mutating func put(_ text: String) {
        buffer.writeString(text)
    }

    public mutating func put(_ text: Substring) {
        buffer.writeSubstring(text)
    }

    /// Escapes over the input's UTF-8 rather than over its `String` indices,
    /// which is what the default does. Both write the same bytes; this one
    /// never asks the string for an index, and copies each unescaped run into
    /// the response buffer with one `writeBytes`.
    public mutating func putEscaped(_ text: String) {
        var text = text

        text.withUTF8 { bytes in
            var runStart = 0

            for index in 0 ..< bytes.count {
                guard let entity = htmlEntity(for: bytes[index]) else { continue }

                if index > runStart {
                    buffer.writeBytes(UnsafeBufferPointer(rebasing: bytes[runStart ..< index]))
                }

                buffer.writeString(entity)
                runStart = index + 1
            }

            if runStart < bytes.count {
                buffer.writeBytes(UnsafeBufferPointer(rebasing: bytes[runStart ..< bytes.count]))
            }
        }
    }
}
