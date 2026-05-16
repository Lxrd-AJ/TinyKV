import Foundation
import NIO
import TinyKVCommon

final class SimpleClientHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Message
    typealias OutboundOut = Message
    
    let responsePromise: EventLoopPromise<String>?

    init(promise: EventLoopPromise<String>? = nil) {
        self.responsePromise = promise
    }

    func channelActive(context: ChannelHandlerContext) {
        let messages = [
            Message(contents: "GET"),
            Message(contents: "PUT"),
            Message(contents: "UPDATE"),
        ]

        print("[Channel active]: Would send \(messages.count) entries")
        
        for (index, msg) in messages.enumerated() {
            // Flush on the last message
            if index == messages.count - 1 {
                context.writeAndFlush(self.wrapOutboundOut(msg), promise: nil)
            } else {
                context.write(self.wrapOutboundOut(msg), promise: nil)
            }
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = self.unwrapInboundIn(data)
        print("Received: \(message.contents.trimmingCharacters(in: .whitespacesAndNewlines))")
        responsePromise?.succeed(message.contents)
        
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
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandlers([
                        ByteToMessageHandler(MessageDecoder()),
                        MessageToByteHandler(MessageEncoder()),
                        SimpleClientHandler()
                    ])
                }
            }

        let host = "127.0.0.1"
        let port = PORT
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
