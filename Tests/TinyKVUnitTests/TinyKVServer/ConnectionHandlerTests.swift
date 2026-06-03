import Testing
import NIO
import NIOEmbedded
@testable import TinyKVServer
@testable import TinyKVCommon

struct ConnectionHandlerTests {
    private let allocator = ByteBufferAllocator()

    private func makeBuf(_ s: String) -> ByteBuffer {
        var b = allocator.buffer(capacity: s.utf8.count)
        b.writeString(s)
        return b
    }

    private func getString(_ b: ByteBuffer) -> String {
        return b.getString(at: b.readerIndex, length: b.readableBytes) ?? ""
    }
    
    @Test
    func testConnectionHandlerStreamHandling() async throws {
        let engine = TinyKVEngine()
        let handler = ConnectionHandler(engine: engine)
        let channel = NIOAsyncTestingChannel()
        
        // Wrap the channel in a NIOAsyncChannel
        let wrappedChannel = try await channel.testingEventLoop.executeInContext {
            try NIOAsyncChannel<Request, Response>(wrappingChannelSynchronously: channel)
        }
        
        // Start handling in the background
        let handleTask = Task {
            try await wrappedChannel.executeThenClose { inbound, outbound in
                await handler.handle(inbound: inbound, outbound: outbound)
            }
        }
        
        // 1. Push a SET request
        try await channel.writeInbound(Request(contents: [makeBuf("SET"), makeBuf("stream_key"), makeBuf("stream_value")]))
        
        // 2. Read the response
        let setResponse = try await channel.waitForOutboundWrite(as: Response.self)
        #expect(setResponse.statusCode == .success)
        #expect(getString(setResponse.body) == "OK")
        
        // 3. Push a GET request
        try await channel.writeInbound(Request(contents: [makeBuf("GET"), makeBuf("stream_key")]))
        
        // 4. Read the response
        let getResponse = try await channel.waitForOutboundWrite(as: Response.self)
        #expect(getResponse.statusCode == .success)
        #expect(getString(getResponse.body) == "stream_value")
        
        // 5. Close inbound to finish the loop
        try await channel.testingEventLoop.executeInContext {
            channel.pipeline.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        }
        
        _ = try await handleTask.value
    }
    
    @Test 
    func testConnectionHandlerGetsDataFromStore() async throws {
        let engine = TinyKVEngine()
        
        // Pre-populate the actor
        await engine._testOnlySet(key: makeBuf("key1"), value: makeBuf("hello_world"))
        
        let request = Request(contents: [makeBuf("GET"), makeBuf("key1")])
        let response = await engine.process(request)
        
        #expect(getString(response.body) == "hello_world")
    }

    @Test
    func testConnectionHandlerSetsDataInStore() async throws {        
        let engine = TinyKVEngine()

        let request = Request(contents: [makeBuf("SET"), makeBuf("key2"), makeBuf("new_value")])
        let response = await engine.process(request)
        
        #expect(getString(response.body) == "OK")
        
        // Verify the actor actually stored it
        let storedValue = await engine._testOnlyGet(key: makeBuf("key2"))
        #expect(storedValue != nil)
        #expect(getString(storedValue!) == "new_value")
    }
    
    @Test
    func testConnectionHandlerHandlesMissingArguments() async throws {
        let engine = TinyKVEngine()
        
        let response = await engine.process(Request(contents: [makeBuf("GET")]))
        #expect(getString(response.body).starts(with: "ERROR"))
    }

    @Test
    func testConnectionHandlerHandlesDelete() async throws {
        let engine = TinyKVEngine()
        
        await engine._testOnlySet(key: makeBuf("delete_me"), value: makeBuf("value"))
        
        let response = await engine.process(Request(contents: [makeBuf("DELETE"), makeBuf("delete_me")]))
        
        #expect(response.statusCode == .success)
        #expect(getString(response.body) == "OK")
        
        let value = await engine._testOnlyGet(key: makeBuf("delete_me"))
        #expect(value == nil)
    }

    @Test
    func testConnectionHandlerHandlesDeleteMissingKey() async throws {
        let engine = TinyKVEngine()
        
        let response = await engine.process(
            Request(contents: [makeBuf("DELETE"), makeBuf("non_existent")])
        )
        
        #expect(response.statusCode == .keyNotFound)
    }

    @Test
    func testConnectionHandlerHandlesUnrecognisedCommand() async throws {
        let engine = TinyKVEngine()
        
        let response = await engine.process(Request(contents: [makeBuf("UNKNOWN"), makeBuf("arg")]))
        #expect(response.statusCode == .unrecognisedCommand)
        #expect(getString(response.body).contains("Unrecognised command"))
    }
}