import NIO
import TinyKVCommon

public final class RequestEncoder: MessageToByteEncoder {
    public typealias OutboundIn = Request

    public init() {}

    public func encode(data: Request, out: inout ByteBuffer) throws {
        // Write number of strings (4 bytes)
        out.writeInteger(UInt32(data.contents.count), endianness: .little)
        
        for buffer in data.contents {
            // Write length of buffer (4 bytes)
            out.writeInteger(UInt32(buffer.readableBytes), endianness: .little)
            // Write buffer
            var content = buffer
            out.writeBuffer(&content)
        }
    }
}