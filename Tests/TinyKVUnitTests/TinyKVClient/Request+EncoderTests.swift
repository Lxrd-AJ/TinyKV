import Testing
import NIO
@testable import TinyKVClient
import TinyKVCommon

struct RequestEncoderTests {
    let allocator = ByteBufferAllocator()
    let channel = EmbeddedChannel()

    @Test 
    func testCanEncodeRequest() throws {
        try channel.pipeline.syncOperations.addHandlers([
            MessageToByteHandler(RequestEncoder())
        ])

        let request = Request(contents: ["GET", "key1"])
        try channel.writeOutbound(request)

        guard var buffer: ByteBuffer = try channel.readOutbound() else {
            Issue.record("Expected to read a ByteBuffer but got nil")
            return
        }

        let nstr = buffer.readInteger(endianness: .little, as: UInt32.self)
        #expect(nstr == 2)

        let len1 = buffer.readInteger(endianness: .little, as: UInt32.self)
        #expect(len1 == 3)
        let str1 = buffer.readString(length: Int(len1!))
        #expect(str1 == "GET")

        let len2 = buffer.readInteger(endianness: .little, as: UInt32.self)
        #expect(len2 == 4)
        let str2 = buffer.readString(length: Int(len2!))
        #expect(str2 == "key1")

        _ = try channel.finish()
    }
}
