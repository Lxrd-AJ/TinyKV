import Foundation
import NIO

public let PORT: Int = 6379
public let MAX_PAYLOAD_SIZE: Int = 512 * 1024 * 1024 // 512 MB

public struct Message: Sendable {
    public let contents: String

    public init(contents: String) {
        self.contents = contents
    }
}

public actor KVStore {
    private let store: HashTable

    public init(capacity: Int = 1024) {
        self.store = HashTable(capacity: capacity)
    }

    public func get(key: ByteBuffer) -> ByteBuffer? {
        return store.lookup(key: key)?.pointee.value
    }

    public func set(key: ByteBuffer, value: ByteBuffer) {
        store.add(key: key, value: value)
    }

    public func delete(key: ByteBuffer) -> ByteBuffer? {
        return store.delete(key: key)
    }
}

public actor TinyKVEngine {
    private let store: KVStore = KVStore()
    private let allocator = ByteBufferAllocator()

    public init() {}

    private func makeBuffer(_ string: String) -> ByteBuffer {
        var buffer = self.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }

    public func process(_ request: Request) async -> Response {
        guard let commandBuf = request.contents.first,
              let command = commandBuf.getString(at: commandBuf.readerIndex, length: commandBuf.readableBytes)?.uppercased() else {
            return Response(statusCode: .emptyRequest, body: self.makeBuffer("ERROR: Empty request"))
        }

        switch command {
            case "GET":
                guard request.contents.count == 2 else {
                    return Response(statusCode: .badRequest, body: self.makeBuffer("ERROR: GET requires exactly 1 argument"))
                }
                let key = request.contents[1]
                let value = await self.store.get(key: key)
                if let value = value {
                    return Response(statusCode: .success, body: value)
                } else {
                    // We need to keep the key as a string for the error message
                    let keyStr = key.getString(at: key.readerIndex, length: key.readableBytes) ?? "unknown"
                    return Response(
                        statusCode: .success,
                        body: self.makeBuffer("ERROR: Key '\(keyStr)' not found")
                    )
                }

            case "SET":
                guard request.contents.count == 3 else {
                    return Response(statusCode: .badRequest, body: self.makeBuffer("ERROR: SET requires exactly 2 arguments"))
                }
                let key = request.contents[1]
                let value = request.contents[2]
                await store.set(key: key, value: value)
                return Response(statusCode: .success, body: self.makeBuffer("OK"))

            case "DELETE":
                guard request.contents.count == 2 else {
                    return Response(statusCode: .badRequest, body: self.makeBuffer("ERROR: DELETE requires exactly 1 argument"))
                }
                let key = request.contents[1]
                let deleted = await store.delete(key: key)
                if deleted != nil {
                    return Response(statusCode: .success, body: self.makeBuffer("OK"))
                } else {
                    let keyStr = key.getString(at: key.readerIndex, length: key.readableBytes) ?? "unknown"
                    return Response(statusCode: .keyNotFound, body: self.makeBuffer("ERROR: Key '\(keyStr)' not found"))
                }

            default:
                return Response(statusCode: .unrecognisedCommand, body: self.makeBuffer("ERROR: Unrecognised command '\(command)'"))
        }
    }
}

public enum ResponseStatus: UInt8, Sendable {
    case success = 0
    case notFound = 1
    case unrecognisedCommand = 2
    case emptyRequest = 3
    case badRequest = 4
    case keyNotFound = 5
}

public struct Request: Sendable {
    public let contents: [ByteBuffer]

    public init(contents: [ByteBuffer]) {
        self.contents = contents
    }
}

public struct Response: Sendable {
    public let statusCode: ResponseStatus
    public let body: ByteBuffer

    public init(statusCode: ResponseStatus, body: ByteBuffer) {
        self.statusCode = statusCode
        self.body = body
    }
}