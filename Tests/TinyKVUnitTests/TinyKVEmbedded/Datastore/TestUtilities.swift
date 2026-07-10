import Foundation
import NIOCore
@testable import TinyKVEmbedded

struct KVPair {
    let key: String
    let value: String
    private(set) var rawKey: ByteBuffer
    private(set) var rawValue: ByteBuffer

    init(key: String, value: String, allocator: ByteBufferAllocator = ByteBufferAllocator()) {
        self.key = key
        self.value = value

        self.rawKey = allocator.buffer(capacity: 16)
        self.rawKey.writeString(key)
        self.rawValue = allocator.buffer(capacity: 16)
        self.rawValue.writeString(value)
    }
}

@discardableResult
func insert(_ insertCount: Int, into hashTable: Datastorage, using allocator: ByteBufferAllocator = ByteBufferAllocator()) -> [KVPair] {
    var entries: [KVPair] = []
    for i in 0..<insertCount {
        let pair = KVPair(key: "key_\(i)", value: "value_\(i)", allocator: allocator)
        hashTable.insert(key: pair.rawKey, value: pair.rawValue)
        entries.append(pair)
    }
    return entries
}