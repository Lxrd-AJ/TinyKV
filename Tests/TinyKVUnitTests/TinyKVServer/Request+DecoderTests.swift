import Testing
import NIO
@testable import TinyKVServer
import TinyKVEmbedded

struct RequestDecoderTests {
    let allocator = ByteBufferAllocator()
    let channel = EmbeddedChannel()

    @Test 
    func testCanDecodeRequestFormat() async throws {
        let messages = ["GET", "<key1>", "SET", "<key2>", "<value>"]
        
        try channel.pipeline.syncOperations.addHandlers([
            ByteToMessageHandler(RequestDecoder())
        ])
        
        let requestBuffer = self.makeExampleRequest(from: messages)
        try channel.writeInbound(requestBuffer)
        
        guard let decodedRequest: Request = try channel.readInbound() else {
            Issue.record("Expected to read a Request but got nil")
            return
        }
        
        #expect(decodedRequest.contents.map { $0.getString(at: $0.readerIndex, length: $0.readableBytes) } == messages)
        
        _ = try channel.finish()
    }

    @Test
    func testCanDecodeMultipleRequestsOnSameConnection() async throws {
        try channel.pipeline.syncOperations.addHandlers([
            ByteToMessageHandler(RequestDecoder())
        ])
        
        // 1. Send the first request
        let messages1 = ["GET", "key1"]
        let request1Buffer = self.makeExampleRequest(from: messages1)
        try channel.writeInbound(request1Buffer)
        
        guard let decodedRequest1: Request = try channel.readInbound() else {
            Issue.record("Expected to read the first Request but got nil")
            return
        }
        #expect(decodedRequest1.contents.map { $0.getString(at: $0.readerIndex, length: $0.readableBytes) } == messages1)
        
        // 2. Send the second request on the same channel
        let messages2 = ["SET", "key2", "value2"]
        let request2Buffer = self.makeExampleRequest(from: messages2)
        try channel.writeInbound(request2Buffer)
        
        guard let decodedRequest2: Request = try channel.readInbound() else {
            Issue.record("Expected to read the second Request but got nil")
            return
        }
        #expect(decodedRequest2.contents.map { $0.getString(at: $0.readerIndex, length: $0.readableBytes) } == messages2)
        
        _ = try channel.finish()
    }

    @Test 
    func canQueueUpMultipleRequestsOnTheConnection() async throws {
        try channel.pipeline.syncOperations.addHandlers([
            ByteToMessageHandler(RequestDecoder())
        ])

        let messages1 = ["GET", "key1"]
        try channel.writeInbound(self.makeExampleRequest(from: messages1))
        let messages2 = ["UPDATE", "key1", "<newValue>"]
        try channel.writeInbound(self.makeExampleRequest(from: messages2))

        guard let decoded1: Request = try channel.readInbound() else {
            Issue.record("Expected to read the first request but got nil")
            return
        }
        
        guard let decoded2: Request = try channel.readInbound() else {
            Issue.record("Expected to read the second request but got nil")
            return
        }

        #expect(decoded1.contents.map { $0.getString(at: $0.readerIndex, length: $0.readableBytes) } == messages1)
        #expect(decoded2.contents.map { $0.getString(at: $0.readerIndex, length: $0.readableBytes) } == messages2)

        _ = try channel.finish()
    }

    func makeExampleRequest(from messages: [String]) -> ByteBuffer {
        var buffer = allocator.buffer(capacity: 10)

        // Prepare messages in the format
        // ```
        // ------------------------------------------------------------------------
        // | nstr (4 bytes) │ len (4 bytes) │ str1 │ len │ str2 │ ... │ len │ strn │
        // ------------------------------------------------------------------------
        // ````
        // 1. Encode the number of strings
        buffer.writeInteger(UInt32(messages.count), endianness: .little)
        // 2. Encode the individual strings
        for msg in messages {
            let length = UInt32(msg.utf8.count)
            buffer.writeInteger(length, endianness: .little)
            buffer.writeString(msg)
        }

        return buffer
    }
}
