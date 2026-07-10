import Foundation
import NIO
import TinyKVEmbedded

public actor TinyKVEngine {
    private let store: KVStore = KVStore()
    private let allocator = ByteBufferAllocator()

    public init() {}

    internal func _testOnlyGet(key: ByteBuffer) -> ByteBuffer? {
        return self.store.get(key: key)
    }

    internal func _testOnlySet(key: ByteBuffer, value: ByteBuffer) {
        self.store.set(key: key, value: value)
    }

    internal func _testOnlyDelete(key: ByteBuffer) throws(TinyError) {
        return try self.store.delete(key: key)
    }

    private func makeBuffer(_ string: String) -> ByteBuffer {
        var buffer = self.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }

    private func makeBuffer(_ int: Int) -> ByteBuffer {
        var buffer = self.allocator.buffer(capacity: Int(int.bitWidth / 8))
        buffer.writeInteger(int)
        return buffer
    }

    /// Similar to `process` but designed to be used in a local context
    /// e.g 
    /// ```
    /// let kv = TinyKVEngine()
    /// await kv.execute(command: ["SET", "user:1", "aj"])
    /// let result = await kv.execute(command: ["GET", "user:1"])
    /// ```
    /// Other methods like `ft`, `set`, `get` can also be exposed here
    public func execute(command: String) {
        // TODO:
    }

    public func process(_ request: Request) -> Response {
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
                let value = self.store.get(key: key)
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
                store.set(key: key, value: value)
                return Response(statusCode: .success, body: self.makeBuffer("OK"))

            case "DELETE":
                guard request.contents.count == 2 else {
                    return Response(statusCode: .badRequest, body: self.makeBuffer("ERROR: DELETE requires exactly 1 argument"))
                }
                let key = request.contents[1]
                do {
                    try store.delete(key: key)
                    return Response(statusCode: .success, body: self.makeBuffer("OK"))
                }catch {
                    let keyStr = key.getString(at: key.readerIndex, length: key.readableBytes) ?? "unknown"
                    return Response(statusCode: .keyNotFound, body: self.makeBuffer("ERROR[\(error.localizedDescription)] occurred for Key '\(keyStr)'"))
                }

            default:
                return Response(statusCode: .unrecognisedCommand, body: self.makeBuffer("ERROR: Unrecognised command '\(command)'"))
        }
    }
}