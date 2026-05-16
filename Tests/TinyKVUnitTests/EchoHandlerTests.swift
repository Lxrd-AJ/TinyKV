import Testing
import NIO
@testable import TinyKV

struct EchoHandlerTests {
    @Test 
    func testEchoHandlerWithEmbeddedChannel() throws {
        // 1. Create the EmbeddedChannel
        let channel = EmbeddedChannel()
        
        // 2. Add our handler to the pipeline
        try channel.pipeline.addHandler(EchoHandler()).wait()
        
        // 3. Prepare some test data
        let message = "Hello Embedded TinyKV"
        var buffer = channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        
        // 4. "Write" data inbound as if it came from the network
        try channel.writeInbound(buffer)
        
        // 5. "Read" data outbound as if it's being sent back to the network
        guard var outboundBuffer: ByteBuffer = try channel.readOutbound() else {
            Issue.record("Expected to read a ByteBuffer from outbound")
            return
        }
        
        // 6. Assert the echo worked
        let received = outboundBuffer.readString(length: outboundBuffer.readableBytes)
        #expect(received == message)
        
        // 7. Clean up
        _ = try channel.finish()
    }
}
