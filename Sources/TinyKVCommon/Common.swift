import Foundation
import NIO

public let PORT: Int = 6379

public struct Message: Sendable {
    public let contents: String

    public init(contents: String) {
        self.contents = contents
    }
}

public actor KVStore {
    // In-memory key-value store. Not optimized for performance or memory usage.
    // For better performance, we'd use a `[String: ByteBuffer]` and avoid unnecessary string copying, but this is simpler for demonstration purposes.
    var store: [String: String] = [:]

    public init() {}

    public func get(key: String) -> String? {
        return store[key]
    }

    public func set(key: String, value: String) {
        store[key] = value
    }

    public func delete(key: String) -> String? {
        return store.removeValue(forKey: key)
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
    public let contents: [String]

    public init(contents: [String]) {
        self.contents = contents
    }
}

public struct Response: Sendable {
    public let statusCode: ResponseStatus
    public let body: String

    public init(statusCode: ResponseStatus, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}