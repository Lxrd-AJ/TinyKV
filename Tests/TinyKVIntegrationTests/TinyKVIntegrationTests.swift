import Testing
import NIO
import Foundation
@testable import TinyKV

final class ClientResponseHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    let responsePromise: EventLoopPromise<String>

    init(promise: EventLoopPromise<String>) {
        self.responsePromise = promise
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        if let received = buffer.readString(length: buffer.readableBytes) {
            responsePromise.succeed(received)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        responsePromise.fail(error)
        context.close(promise: nil)
    }
}

struct TinyKVIntegrationTests {
    @Test 
    func testEchoServer() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // 3. Configure the ServerBootstrap
        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(EchoHandler())
            }

        // Bind to port 0 to let the OS assign an available port
        let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
        let port = serverChannel.localAddress!.port!
        
        let promise: EventLoopPromise<String> = group.next().makePromise()
        
        let clientBootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandler(ClientResponseHandler(promise: promise))
            }
        
        let clientChannel = try await clientBootstrap.connect(host: "127.0.0.1", port: port).get()
        
        let message = "Hello TinyKV"
        var buffer = clientChannel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        
        try await clientChannel.writeAndFlush(buffer).get()
        
        let received = try await promise.futureResult.get()
        #expect(received == message)
        
        try await clientChannel.close().get()
        try await serverChannel.close().get()
        
        // Finalize
        try await group.shutdownGracefully()
    }
}
