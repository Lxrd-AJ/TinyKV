import Testing
import NIO
@testable import TinyKVClient

struct SimpleClientHandlerTests {
    @Test 
    func testClientSendsPingOnActive() throws {
        // 1. Create the EmbeddedChannel
        let channel = EmbeddedChannel()
        
        // 2. Add our client handler to the pipeline
        try channel.pipeline.addHandler(SimpleClientHandler()).wait()
        
        // 3. Trigger channelActive (simulate the connection opening)
        channel.pipeline.fireChannelActive()
        
        // 4. "Read" data outbound as if it's being sent from the client to the network
        guard var outboundBuffer: ByteBuffer = try channel.readOutbound() else {
            Issue.record("Expected to read a ByteBuffer from outbound")
            return
        }
        
        // 5. Assert the client automatically sent "PING"
        let sent = outboundBuffer.readString(length: outboundBuffer.readableBytes)
        #expect(sent == "PING")
        
        // 6. Clean up
        _ = try? channel.finish()
    }
    
    @Test 
    func testClientFulfillsPromiseOnRead() throws {
        let channel = EmbeddedChannel()
        let loop = channel.eventLoop as! EmbeddedEventLoop
        let promise: EventLoopPromise<String> = loop.makePromise()
        
        try channel.pipeline.addHandler(SimpleClientHandler(promise: promise)).wait()
        
        // 1. Simulate server sending "PONG" back
        let message = "PONG\n"
        var buffer = channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        
        try channel.writeInbound(buffer)
        
        // 2. Verify the promise was fulfilled with the message
        let received = try promise.futureResult.wait()
        #expect(received == message)
        
        _ = try? channel.finish()
    }
}
