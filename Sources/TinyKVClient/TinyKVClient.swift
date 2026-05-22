import Foundation
import NIO
import TinyKVCommon

final class SimpleClientHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Response
    typealias OutboundOut = Request
    
    let responsePromise: EventLoopPromise<String>?

    init(promise: EventLoopPromise<String>? = nil) {
        self.responsePromise = promise
    }

    func channelActive(context: ChannelHandlerContext) {
        let messages = [
            Request(contents: ["GET", "key1"]),
            Request(contents: ["SET", "key1", "value1"]),
            Request(contents: ["UPDATE"]),
            Request(contents: ["DELETE", "key1"])
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
        let response = self.unwrapInboundIn(data)
        print("Received: \(response.statusCode) - \(response.body)")
        responsePromise?.succeed(response.body)
        
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
                        MessageToByteHandler(RequestEncoder()),
                        ByteToMessageHandler(ResponseDecoder()),
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
