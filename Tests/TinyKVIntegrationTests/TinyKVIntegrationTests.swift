import Testing
import NIO
import Foundation
@testable import TinyKVServer
@testable import TinyKVClient
@testable import TinyKVCommon

struct TinyKVIntegrationTests {
    @Test 
    func testServerAndClientIntegration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let engine = TinyKVEngine()
        
        // 1. Configure the ServerBootstrap
        let connectionHandler = ConnectionHandler(engine: engine)
        let serverBootstrap = ServerBootstrap(group: group)

        // Bind to port 0 to let the OS assign an available port
        let serverChannel = try await serverBootstrap.bind(
            host: "127.0.0.1",
            port: 0
        ) { childChannel in
            childChannel.eventLoop.makeCompletedFuture {
                try childChannel.pipeline.syncOperations.addHandlers([
                    ByteToMessageHandler(RequestDecoder()),
                    MessageToByteHandler(ResponseEncoder())
                ])
                return try NIOAsyncChannel<Request, Response>(
                    wrappingChannelSynchronously: childChannel
                )
            }
        }
        
        let port = serverChannel.channel.localAddress!.port!
        let allocator = ByteBufferAllocator()
        
        let serverTask = Task {
            try await withThrowingDiscardingTaskGroup { taskGroup in
                try await serverChannel.executeThenClose { serverChannelInbound in
                    for try await childChannel in serverChannelInbound {
                        taskGroup.addTask {
                            try await childChannel.executeThenClose { inbound, outbound in
                                await connectionHandler.handle(inbound: inbound, outbound: outbound)
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Setup the Client
        let clientBootstrap = ClientBootstrap(group: group)
        
        let clientChannel = try await clientBootstrap.connect(
            host: "127.0.0.1",
            port: port
        ) { channel in
            channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHandlers([
                    MessageToByteHandler(RequestEncoder()),
                    ByteToMessageHandler(ResponseDecoder())
                ])
                return try NIOAsyncChannel<Response, Request>(
                    wrappingChannelSynchronously: channel
                )
            }
        }
        
        // 3. Connect and send a sequence of requests
        var testKeyBuf = allocator.buffer(capacity: 32)
        testKeyBuf.writeString("integration_test_key")
        var testValBuf = allocator.buffer(capacity: 32)
        testValBuf.writeString("success")
        await engine._testOnlySet(key: testKeyBuf, value: testValBuf)
        
        try await clientChannel.executeThenClose { inbound, outbound in
            // Helper to make buffers
            func makeBuf(_ s: String) -> ByteBuffer {
                var b = allocator.buffer(capacity: s.utf8.count)
                b.writeString(s)
                return b
            }

            // SET
            try await outbound.write(Request(contents: [makeBuf("SET"), makeBuf("multi_key"), makeBuf("multi_value")]))
            
            // GET
            try await outbound.write(Request(contents: [makeBuf("GET"), makeBuf("multi_key")]))
            
            // DELETE
            try await outbound.write(Request(contents: [makeBuf("DELETE"), makeBuf("multi_key")]))
            
            var iterator = inbound.makeAsyncIterator()
            
            // Verify SET response
            if let response = try await iterator.next() {
                #expect(response.body.getString(at: response.body.readerIndex, length: response.body.readableBytes) == "OK")
            } else {
                Issue.record("Did not receive SET response")
            }
            
            // Verify GET response
            if let response = try await iterator.next() {
                #expect(response.body.getString(at: response.body.readerIndex, length: response.body.readableBytes) == "multi_value")
            } else {
                Issue.record("Did not receive GET response")
            }
            
            // Verify DELETE response
            if let response = try await iterator.next() {
                // TODO: Fix this test once HashTable.delete is implemented
                withKnownIssue("DELETE is not yet implemented in HashTable") {
                    #expect(response.body.getString(at: response.body.readerIndex, length: response.body.readableBytes) == "OK")
                }
            } else {
                Issue.record("Did not receive DELETE response")
            }
        }
        
        // 5. Cleanup
        serverTask.cancel()
        try? await serverChannel.channel.close().get()
        
        try await group.shutdownGracefully()
    }
}
