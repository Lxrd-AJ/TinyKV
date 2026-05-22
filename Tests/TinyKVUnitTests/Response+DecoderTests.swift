import Testing
import NIO
@testable import TinyKVClient
import TinyKVCommon

struct ResponseDecoderTests {
    let allocator = ByteBufferAllocator()
    let channel = EmbeddedChannel()

    @Test 
    func testCanDecodeResponse() throws {
        try channel.pipeline.syncOperations.addHandlers([
            ByteToMessageHandler(ResponseDecoder())
        ])

        var buffer = allocator.buffer(capacity: 10)
        buffer.writeInteger(ResponseStatus.success.rawValue, endianness: .little, as: UInt8.self)
        buffer.writeInteger(UInt32(2), endianness: .little)
        buffer.writeString("OK")

        try channel.writeInbound(buffer)

        guard let response: Response = try channel.readInbound() else {
            Issue.record("Expected to read a Response but got nil")
            return
        }

        #expect(response.statusCode == .success)
        #expect(response.body == "OK")

        _ = try channel.finish()
    }

    @Test
    func testWaitUntilMoreDataForResponse() throws {
        try channel.pipeline.syncOperations.addHandlers([
            ByteToMessageHandler(ResponseDecoder())
        ])

        var buffer = allocator.buffer(capacity: 10)
        buffer.writeInteger(ResponseStatus.success.rawValue, endianness: .little, as: UInt8.self)
        buffer.writeInteger(UInt32(2), endianness: .little)
        // No body yet

        try channel.writeInbound(buffer)
        let firstRead: Response? = try channel.readInbound()
        #expect(firstRead == nil)

        // Now write the body
        var bodyBuffer = allocator.buffer(capacity: 2)
        bodyBuffer.writeString("OK")
        try channel.writeInbound(bodyBuffer)

        guard let response: Response = try channel.readInbound() else {
            Issue.record("Expected to read a Response but got nil")
            return
        }

        #expect(response.statusCode == .success)
        #expect(response.body == "OK")

        _ = try channel.finish()
    }
}
