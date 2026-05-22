import NIO
import TinyKVCommon

public final class RequestEncoder: MessageToByteEncoder {
    public typealias OutboundIn = Request

    public init() {}

    public func encode(data: Request, out: inout ByteBuffer) throws {
        // Write number of strings (4 bytes)
        out.writeInteger(UInt32(data.contents.count), endianness: .little)
        
        for string in data.contents {
            // Write length of string (4 bytes)
            out.writeInteger(UInt32(string.utf8.count), endianness: .little)
            // Write string
            out.writeString(string)
        }
    }
}