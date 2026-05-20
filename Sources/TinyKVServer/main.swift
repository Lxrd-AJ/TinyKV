import NIO
import TinyKVCommon
import Foundation


final class RequestHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Request
    typealias OutboundOut = Message

    let store: KVStore

    init(store: KVStore) {
        self.store = store
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        print("Received request: \(request.contents)")
        
        // Ensure we have a command
        guard let command = request.contents.first?.uppercased() else {
            let response = Message(contents: "ERROR: Empty request")
            context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
            return
        }

        let channel = context.channel
        
        // Spawn an unstructured Task to interact with the actor
        Task {
            var responseStr = "OK"
            
            if command == "GET" && request.contents.count == 2 {
                let key = request.contents[1]
                let value = await store.get(key: key)
                responseStr = value ?? "(nil)"
            } else if command == "SET" && request.contents.count == 3 {
                let key = request.contents[1]
                let value = request.contents[2]
                await store.set(key: key, value: value)
                responseStr = "OK"
            } else {
                responseStr = "ERROR: Unknown command or wrong number of arguments"
            }
            
            let response = Message(contents: responseStr)
            
            // Hop back to the event loop to write the response
            channel.eventLoop.execute {
                _ = channel.writeAndFlush(response)
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Error: \(error)")
        context.close(promise: nil)
    }
}

@main
struct TinyKVServer {
    static func main() async throws {
        let store = KVStore()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // We use a manual shutdown approach because 'defer' with 'try await' 
        // inside an async main is the correct modern pattern.
        // Note: shutdownGracefully() returns a future we can await.
        
        // Configure the ServerBootstrap
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandlers([
                        ByteToMessageHandler(RequestDecoder()),
                        MessageToByteHandler(MessageEncoder()),
                        RequestHandler(store: store)
                    ])
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        // Bind to a port and start listening
        let host = "127.0.0.1"

        do {
            let channel = try await bootstrap.bind(host: host, port: PORT).get()
            print("Server running on \(channel.localAddress!)")

            // Wait for the server socket to close
            try await channel.closeFuture.get()
        } catch {
            print("Failed to start server: \(error)")
        }

        // Graceful shutdown
        try await group.shutdownGracefully()
        print("Server closed")
    }
}
