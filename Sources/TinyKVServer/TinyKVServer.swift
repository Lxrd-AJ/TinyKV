import NIO
import TinyKVCommon
import Foundation

@main
struct TinyKVServer {
    static func main() async throws {
        let engine: TinyKVEngine = TinyKVEngine()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let connectionHandler = ConnectionHandler(engine: engine)
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let host = "127.0.0.1"

        do {
            let serverChannel = try await bootstrap.bind(
                host: host,
                port: PORT
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

            print("Server running on \(serverChannel.channel.localAddress!)")

            try await withThrowingDiscardingTaskGroup { taskGroup in
                try await serverChannel.executeThenClose { serverChannelInbound in
                    for try await childChannel in serverChannelInbound {
                        taskGroup.addTask {
                            do {
                                try await childChannel.executeThenClose { inbound, outbound in
                                    await connectionHandler.handle(inbound: inbound, outbound: outbound)
                                }
                            } catch {
                                print("Child channel error: \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to start server: \(error)")
        }

        try await group.shutdownGracefully()
        print("Server closed")
    }
}
