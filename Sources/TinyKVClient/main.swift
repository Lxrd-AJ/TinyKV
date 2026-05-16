import Foundation
import NIO

final class SimpleClientHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    let responsePromise: EventLoopPromise<String>?

    init(promise: EventLoopPromise<String>? = nil) {
        self.responsePromise = promise
    }

    func channelActive(context: ChannelHandlerContext) {
        let message = "PING"
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        print("Sending: \(message)")
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        if let string = buffer.readString(length: buffer.readableBytes) {
            print("Received: \(string.trimmingCharacters(in: .whitespacesAndNewlines))")
            responsePromise?.succeed(string)
        }
        
        // Disconnect after receiving a response for testing purposes
        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Error: \(error)")
        responsePromise?.fail(error)
        context.close(promise: nil)
    }
}

@main
struct TinyKVClientApp {
    static func main() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(SimpleClientHandler())
            }

        let host = "127.0.0.1"
        let port = 6379

        do {
            print("Connecting to \(host):\(port)...")
            let channel = try await bootstrap.connect(host: host, port: port).get()
            print("Connected to \(channel.remoteAddress!)")
            
            // Wait until the channel is closed
            try await channel.closeFuture.get()
            print("Connection closed")
        } catch {
            print("Failed to connect: \(error)")
        }
        
        try await group.shutdownGracefully()
    }
}
