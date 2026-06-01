import NIO
import TinyKVCommon

/// Handles the lifecycle of a single client connection using modern async/await streams.
struct ConnectionHandler: Sendable {
    let engine: TinyKVEngine

    init(engine: TinyKVEngine) {
        self.engine = engine
    }

    /// Takes ownership of the inbound and outbound streams.
    func handle(
        inbound: NIOAsyncChannelInboundStream<Request>,
        outbound: NIOAsyncChannelOutboundWriter<Response>
    ) async {
        print("Client connected")
        do {
            for try await request in inbound {
                print("Received request: \(request.contents)")
                
                // 1. Process the request
                let responseMessage = await self.engine.process(request)
                
                // 2. Write the response back.
                try await outbound.write(responseMessage)
            }
        } catch {
            print("Connection error or client disconnected: \(error)")
        }
        print("Client disconnected cleanly")
    }
}
