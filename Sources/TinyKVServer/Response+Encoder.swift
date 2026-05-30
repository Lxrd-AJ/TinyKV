import NIO
import TinyKVCommon

public final class ResponseEncoder: MessageToByteEncoder {
    public typealias OutboundIn = Response

    public init() {}

    /// Outgoing responses are in the following format
    /// ```
    /// -----------------------------------------
    /// | status (1 byte) │ len (4 bytes) │ body │
    /// -----------------------------------------
    /// ````
    public func encode(data: Response, out: inout ByteBuffer) throws {
        // Write status code (1 byte)
        out.writeInteger(data.statusCode.rawValue, endianness: .little, as: UInt8.self)
        // Write length of body (4 bytes)
        out.writeInteger(UInt32(data.body.readableBytes), endianness: .little)
        // Write body
        var body = data.body
        out.writeBuffer(&body)
    }
}
