import NIO
import TinyKVCommon

public final class ResponseDecoder: ByteToMessageDecoder {
    public typealias InboundOut = Response

    public init() {}

    /// Incoming responses are in the following format
    /// ```
    /// -----------------------------------------
    /// | status (1 byte) │ len (4 bytes) │ body │
    /// -----------------------------------------
    /// ````
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Check if we have at least 5 bytes to read the status and length
        guard let statusCode = buffer.getInteger(at: buffer.readerIndex, endianness: .little, as: UInt8.self),
            let length = buffer.getInteger(at: buffer.readerIndex + 1, endianness: .little, as: UInt32.self) else {
            return .needMoreData
        }

        let totalLength = 1 + 4 + Int(length)
        guard buffer.readableBytes >= totalLength else {
            return .needMoreData
        }

        // Move reader index past the status and length by consuming them
        _ = buffer.readInteger(endianness: .little, as: UInt8.self)! // consumes 1 byte
        _ = buffer.readInteger(endianness: .little, as: UInt32.self)! // consumes 4 bytes

        // Read the body
        guard let body = buffer.readString(length: Int(length)) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Failed to read response body"))
        }

        let response = Response(
            statusCode: ResponseStatus.init(rawValue: statusCode)!, body: body
        )
        context.fireChannelRead(self.wrapInboundOut(response))
        return .continue
    }
}