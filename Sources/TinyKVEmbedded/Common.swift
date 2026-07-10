import Foundation
import NIO

public let PORT: Int = 6379
/// The maximum size in bytes that a request can contain
public let MAX_PAYLOAD_SIZE: Int = 512 * 1024 * 1024 // 512 MB
/// A factor used to determine the threshold for migrating to a new hashtable. Typically used to 
/// define a threshold as `threshold = hashmap.capacity * MAX_LOAD_FACTOR`
let MAX_LOAD_FACTOR: Int = 8
/// A fixed amount of items to progressively migrate from the older hashtable to the newer one.
let AMOUNT_MIGRATION_WORK: Int = 124


public enum TinyError: Error {
    case keyNotFound
}


public struct KVStore {
    private let store: Datastorage

    public init(capacity: UInt = 1024) {
        self.store = HashMap(capacity: capacity)
    }

    public func get(key: ByteBuffer) -> ByteBuffer? {
        return store.lookup(key: key)
    }

    public func set(key: ByteBuffer, value: ByteBuffer) {
        store.insert(key: key, value: value)
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

extension ByteBuffer: @retroactive Comparable {
    // (ByteBuffer already implements `==` via NIOCore, so we only need to provide `<` to satisfy Comparable)
    public static func < (lhs: ByteBuffer, rhs: ByteBuffer) -> Bool {
        // .readableBytesView gives us a Collection of UInt8 bytes,
        // which Swift natively knows how to sort lexicographically!
        return lhs.readableBytesView.lexicographicallyPrecedes(rhs.readableBytesView)
    }
}