import NIO
import TinyKVCommon

public final class RequestDecoder: ByteToMessageDecoder {
    public typealias InboundOut = Request
    
    private var numStringsToRead: Int? = nil
    // This is written for simplicity and clarity, but in a production implementation, we might want to avoid this copy by working with `ByteBuffer` slices directly in our command processing logic.
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
            guard length <= MAX_PAYLOAD_SIZE else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "String length \(length) exceeds maximum allowed size")
                )
            }
            // Check if we have the full payload (4 bytes length + actual string length)
            // `length` could be Int.max, so to avoid overflow in the addition (4 + length), we work with the subtraction instead: we need at least `length` bytes after consuming the 4 bytes of the length header
            guard buffer.readableBytes - 4 >= length else { return .needMoreData }

            // We have enough data! Consume the length header and the string
            _ = buffer.readInteger(endianness: .little, as: UInt32.self)! // consumes 4 bytes
            // Creating a `String` from a `ByteBuffer` involves copying the data, which is not ideal for performance. In a production implementation, we might want to avoid this copy by working with `ByteBuffer` slices directly in our command processing logic. 
            // e.g 
            // ```
            // let stringSlice = buffer.readSlice(length: length)! // This would give us a ByteBuffer slice without copying
            // However, for simplicity and clarity in this example, we'll convert to `String`.
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
