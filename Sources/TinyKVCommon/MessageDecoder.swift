import NIO

public final class MessageDecoder: ByteToMessageDecoder {
    public typealias InboundOut = Message

    public init() {}

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // 1. We need at least 4 bytes to read the length
        guard buffer.readableBytes >= 4 else {
            return .needMoreData
        }
        
        // 2. Read the length without advancing the reader index
        let length = buffer.getInteger(at: buffer.readerIndex, endianness: .little, as: UInt32.self)!
        
        // 3. Ensure we have the full message (4 bytes for length + actual string length)
        let totalRequiredBytes = 4 + Int(length)
        guard buffer.readableBytes >= totalRequiredBytes else {
            return .needMoreData
        }
        
        // 4. We have enough data! Advance the reader index past the length header
        buffer.moveReaderIndex(forwardBy: 4)
        
        // 5. Read the string
        guard let string = buffer.readString(length: Int(length)) else {
            return .needMoreData
        }
        
        // 6. Pass the decoded message to the next handler
        context.fireChannelRead(self.wrapInboundOut(Message(contents: string)))
        return .continue
    }
}
