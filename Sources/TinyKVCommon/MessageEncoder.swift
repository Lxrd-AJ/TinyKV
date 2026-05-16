import NIO

public final class MessageEncoder: MessageToByteEncoder {
    public typealias OutboundIn = Message

    public init() {}

    public func encode(data: Message, out: inout ByteBuffer) throws {
        let length = UInt32(data.contents.utf8.count)
        out.writeInteger(length, endianness: .little)
        out.writeString(data.contents)
    }
}
