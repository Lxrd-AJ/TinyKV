import NIO
import TinyKVCommon

/// Handles the lifecycle of a single client connection using modern async/await streams.
struct ConnectionHandler: Sendable {
    let store: KVStore

    init(store: KVStore) {
        self.store = store
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
                let responseMessage = await process(request: request)
                
                // 2. Write the response back.
                try await outbound.write(responseMessage)
            }
        } catch {
            print("Connection error or client disconnected: \(error)")
        }
        print("Client disconnected cleanly")
    }

    /// Pure, isolated business logic. No knowledge of channels, pipelines, or event loops.
    // For now, the process goes as follows: `ConnectionHandler.process` -> KVStore(set, get etc)`
    // For even better guarantee of atomicity and isolation, we should use a chain `ConnectionHandler.process -> async KVStore.process(Request) -> Datastore(set, get etc)`
    // So that a request is processed atomically end-to-end within the KVStore actor, and the ConnectionHandler is just responsible for translating between the network and the business logic.
    func process(request: Request) async -> Response {
        guard let command = request.contents.first?.uppercased() else {
            return Response(statusCode: .emptyRequest, body: "ERROR: Empty request")
        }

        switch command {
            case "GET":
                guard request.contents.count == 2 else {
                    return Response(statusCode: .badRequest, body: "ERROR: GET requires exactly 1 argument")
                }
                let key = request.contents[1]
                let value = await store.get(key: key)
                return Response(
                    statusCode: .success,
                    body: value ?? "ERROR: Key '\(key)' not found"
                )

            case "SET":
                guard request.contents.count == 3 else {
                    return Response(statusCode: .badRequest, body: "ERROR: SET requires exactly 2 arguments")
                }
                let key = request.contents[1]
                let value = request.contents[2]
                await store.set(key: key, value: value)
                return Response(statusCode: .success, body: "OK")

            case "DELETE":
                guard request.contents.count == 2 else {
                    return Response(statusCode: .badRequest, body: "ERROR: DELETE requires exactly 1 argument")
                }
                let key = request.contents[1]
                let deleted = await store.delete(key: key)
                if deleted != nil {
                    return Response(statusCode: .success, body: "OK")
                } else {
                    return Response(statusCode: .keyNotFound, body: "ERROR: Key '\(key)' not found")
                }

            default:
                return Response(statusCode: .unrecognisedCommand, body: "ERROR: Unrecognised command '\(command)'")
        }
    }
}
