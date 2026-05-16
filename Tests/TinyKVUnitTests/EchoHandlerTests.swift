import Testing
import NIO
@testable import TinyKVServer
import TinyKVCommon

struct EchoHandlerTests {
    @Test 
    func testEchoHandlerWithEmbeddedChannel() throws {
        // 1. Create the EmbeddedChannel
        let channel = EmbeddedChannel()
        
        // 2. Add our handler to the pipeline
        try channel.pipeline.addHandler(EchoHandler()).wait()
        
        // 3. Prepare some test data
        let message = Message(contents: "Hello Embedded TinyKV")
        
        // 4. "Write" data inbound as if it came from the network
        try channel.writeInbound(message)
        
        // 5. "Read" data outbound as if it's being sent back to the network
        guard let outboundMsg: Message = try channel.readOutbound() else {
            Issue.record("Expected to read a Message from outbound")
            return
        }
        
        // 6. Assert the echo worked
        #expect(outboundMsg.contents == "Hello Embedded TinyKV")
        
        // 7. Clean up
        _ = try channel.finish()
    }
}
