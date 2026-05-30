import Testing
import NIO
@testable import TinyKVServer
import TinyKVCommon

struct ResponseEncoderTests {
    let allocator = ByteBufferAllocator()
    let channel = EmbeddedChannel()

    @Test 
    func testCanEncodeResponse() throws {
        try channel.pipeline.syncOperations.addHandlers([
            MessageToByteHandler(ResponseEncoder())
        ])

        let response = Response(statusCode: .success, body: "OK")
        try channel.writeOutbound(response)

        guard var buffer: ByteBuffer = try channel.readOutbound() else {
            Issue.record("Expected to read a ByteBuffer but got nil")
            return
        }

        let status = buffer.readInteger(endianness: .little, as: UInt8.self)
        #expect(status == ResponseStatus.success.rawValue)

        let len = buffer.readInteger(endianness: .little, as: UInt32.self)
        #expect(len == 2)
        let body = buffer.readString(length: Int(len!))
        #expect(body == "OK")

        _ = try channel.finish()
    }
}
