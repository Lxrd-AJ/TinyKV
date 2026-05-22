import Testing
import NIO
import NIOEmbedded
@testable import TinyKVServer
import TinyKVCommon

struct ConnectionHandlerTests {
    
    @Test
    func testConnectionHandlerStreamHandling() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
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
        try await channel.writeInbound(Request(contents: ["SET", "stream_key", "stream_value"]))
        
        // 2. Read the response
        let setResponse = try await channel.waitForOutboundWrite(as: Response.self)
        #expect(setResponse.statusCode == .success)
        #expect(setResponse.body == "OK")
        
        // 3. Push a GET request
        try await channel.writeInbound(Request(contents: ["GET", "stream_key"]))
        
        // 4. Read the response
        let getResponse = try await channel.waitForOutboundWrite(as: Response.self)
        #expect(getResponse.statusCode == .success)
        #expect(getResponse.body == "stream_value")
        
        // 5. Close inbound to finish the loop
        try await channel.testingEventLoop.executeInContext {
            channel.pipeline.fireUserInboundEventTriggered(ChannelEvent.inputClosed)
        }
        
        _ = try await handleTask.value
    }
    
    @Test 
    func testConnectionHandlerGetsDataFromStore() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
        
        // Pre-populate the actor
        await store.set(key: "key1", value: "hello_world")
        
        let request = Request(contents: ["GET", "key1"])
        let response = await handler.process(request: request)
        
        #expect(response.body == "hello_world")
    }

    @Test
    func testConnectionHandlerSetsDataInStore() async throws {        
        let store = KVStore()
        let handler = ConnectionHandler(store: store)

        let request = Request(contents: ["SET", "key2", "new_value"])
        let response = await handler.process(request: request)
        
        #expect(response.body == "OK")
        
        // Verify the actor actually stored it
        let storedValue = await store.get(key: "key2")
        #expect(storedValue == "new_value")
    }
    
    @Test
    func testConnectionHandlerHandlesMissingArguments() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
        
        let response = await handler.process(request: Request(contents: ["GET"]))
        #expect(response.body.starts(with: "ERROR"))
    }

    @Test
    func testConnectionHandlerHandlesDelete() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
        
        await store.set(key: "delete_me", value: "value")
        
        let response = await handler.process(request: Request(contents: ["DELETE", "delete_me"]))
        #expect(response.statusCode == .success)
        #expect(response.body == "OK")
        
        let value = await store.get(key: "delete_me")
        #expect(value == nil)
    }

    @Test
    func testConnectionHandlerHandlesDeleteMissingKey() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
        
        let response = await handler.process(request: Request(contents: ["DELETE", "non_existent"]))
        #expect(response.statusCode == .keyNotFound)
        #expect(response.body.contains("not found"))
    }

    @Test
    func testConnectionHandlerHandlesUnrecognisedCommand() async throws {
        let store = KVStore()
        let handler = ConnectionHandler(store: store)
        
        let response = await handler.process(request: Request(contents: ["UNKNOWN", "arg"]))
        #expect(response.statusCode == .unrecognisedCommand)
        #expect(response.body.contains("Unrecognised command"))
    }
}
