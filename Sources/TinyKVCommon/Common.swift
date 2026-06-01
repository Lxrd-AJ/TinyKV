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

struct KVStore {
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

    public func delete(key: ByteBuffer) throws(TinyError) {
        return try store.delete(key: key)
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

public enum TinyError: Error {
    case keyNotFound
}