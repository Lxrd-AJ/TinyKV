import NIO
import TinyKVCommon
import Foundation

// 1. Define a basic ChannelHandler to handle incoming data
final class EchoHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Message
    typealias OutboundOut = Message

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = self.unwrapInboundIn(data)
        print("Received: \(message.contents)")
        
        // send the incoming data back to the client (echo)
        context.write(self.wrapOutboundOut(message), promise: nil)
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
        // 2. Setup the EventLoopGroup
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // We use a manual shutdown approach because 'defer' with 'try await' 
        // inside an async main is the correct modern pattern.
        // Note: shutdownGracefully() returns a future we can await.
        
        // 3. Configure the ServerBootstrap
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandlers([
                        ByteToMessageHandler(MessageDecoder()),
                        MessageToByteHandler(MessageEncoder()),
                        EchoHandler()
                    ])
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        // 4. Bind to a port and start listening
        let host = "127.0.0.1"

        do {
            let channel = try await bootstrap.bind(host: host, port: PORT).get()
            print("Server running on \(channel.localAddress!)")

            // 5. Wait for the server socket to close
            try await channel.closeFuture.get()
        } catch {
            print("Failed to start server: \(error)")
        }

        // 6. Graceful shutdown
        try await group.shutdownGracefully()
        print("Server closed")
    }
}
