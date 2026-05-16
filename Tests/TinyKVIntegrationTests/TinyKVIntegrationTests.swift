import Testing
import NIO
import Foundation
@testable import TinyKVServer
@testable import TinyKVClient

struct TinyKVIntegrationTests {
    @Test 
    func testServerAndClientIntegration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // 1. Configure the ServerBootstrap
        let serverBootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(EchoHandler())
            }

        // Bind to port 0 to let the OS assign an available port
        let serverChannel = try await serverBootstrap.bind(host: "127.0.0.1", port: 0).get()
        let port = serverChannel.localAddress!.port!
        
        // 2. Setup the Client
        let promise: EventLoopPromise<String> = group.next().makePromise()
        let clientBootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                // We use the actual SimpleClientHandler from our client executable!
                channel.pipeline.addHandler(SimpleClientHandler(promise: promise))
            }
        
        // 3. Connect and let SimpleClientHandler do its thing (it sends "PING" on connect)
        let clientChannel = try await clientBootstrap.connect(host: "127.0.0.1", port: port).get()
        
        // 4. Verify we receive the echoed PING
        let received = try await promise.futureResult.get()
        #expect(received == "PING")
        
        // 5. Cleanup
        try await clientChannel.closeFuture.get()
        try? await serverChannel.close().get()
        
        try await group.shutdownGracefully()
    }
}
