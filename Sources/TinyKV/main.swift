import NIO
import Foundation

// 1. Define a basic ChannelHandler to handle incoming data
final class EchoHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        if let receivedString = buffer.readString(length: buffer.readableBytes) {
            print("Received: \(receivedString.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        
        context.write(data, promise: nil)
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
struct TinyKV {
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
                channel.pipeline.addHandler(EchoHandler())
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        // 4. Bind to a port and start listening
        let host = "127.0.0.1"
        let port = 6379

        do {
            let channel = try await bootstrap.bind(host: host, port: port).get()
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
