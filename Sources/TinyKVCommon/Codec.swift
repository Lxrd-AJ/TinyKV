import NIO

public final class RequestDecoder: ByteToMessageDecoder {
    public typealias InboundOut = Request
    
    private var numStringsToRead: Int? = nil
    private var stringsRead: [String] = []
    
    public init() {}

    /// Incoming requests are in the following format
    /// ```
    /// ------------------------------------------------------------------------
    /// | nstr (4 bytes) │ len (4 bytes) │ str1 │ len │ str2 │ ... │ len │ strn │
    /// ------------------------------------------------------------------------
    /// ````
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {

        if numStringsToRead == nil {
            // No read has taken place, tabula rasa!
            // Ensure that there are 4 bytes to read the total strings in the request
            guard buffer.readableBytes >= 4 else { return .needMoreData }
            self.numStringsToRead = Int(buffer.readInteger(endianness: .little, as: UInt32.self)!)
        }
        let totalRequired = self.numStringsToRead!

        while stringsRead.count < totalRequired {
            // Ensure we have enough for the current message
            // Check for string length header (4 bytes)
            guard buffer.readableBytes >= 4 else { return .needMoreData }
            // Peek at the length without consuming it
            let length = Int(buffer.getInteger(at: buffer.readerIndex, endianness: .little, as: UInt32.self)!)
            // Check if we have the full payload (4 bytes length + actual string length)
            guard buffer.readableBytes >= (4 + length) else { return .needMoreData }

            // We have enough data! Consume the length header and the string
            _ = buffer.readInteger(endianness: .little, as: UInt32.self)! // consumes 4 bytes
            let string = buffer.readString(length: length)!

            stringsRead.append(string)
        }

        // Pass the decoded request to the next handler
        context.fireChannelRead(
            self.wrapInboundOut(Request(contents: stringsRead))
        )

        // Reset state for the next request on this connection!
        self.numStringsToRead = nil
        self.stringsRead.removeAll()

        return .continue
    }
}