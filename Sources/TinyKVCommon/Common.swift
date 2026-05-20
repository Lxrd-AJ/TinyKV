import Foundation
import NIO

public let PORT: Int = 6379

public struct Message: Sendable {
    public let contents: String

    public init(contents: String) {
        self.contents = contents
    }
}

public struct Request: Sendable {
    public let contents: [String]

    public init(contents: [String]) {
        self.contents = contents
    }
}

public actor KVStore {
    var store: [String: String] = [:]

    public init() {}

    public func get(key: String) -> String? {
        return store[key]
    }

    public func set(key: String, value: String) {
        store[key] = value
    }
}