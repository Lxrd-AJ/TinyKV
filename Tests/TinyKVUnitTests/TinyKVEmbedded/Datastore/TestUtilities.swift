import Foundation
import NIOCore
@testable import TinyKVEmbedded

let allocator = ByteBufferAllocator()

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
func insert<Storage: Datastorage>(_ insertCount: Int, into hashTable: Storage, using allocator: ByteBufferAllocator = ByteBufferAllocator()) -> [KVPair] where Storage.Value == ByteBuffer {
    var entries: [KVPair] = []
    for i in 0..<insertCount {
        let pair = KVPair(key: "key_\(i)", value: "value_\(i)", allocator: allocator)
        hashTable.insert(key: pair.rawKey, value: pair.rawValue)
        entries.append(pair)
    }
    return entries
}

func buffer(_ contents: String) -> ByteBuffer {
    return allocator.buffer(string: contents)
}

func randomAlphanumericString(length: Int) -> String {
    let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    // Create a string by mapping 'length' times, picking a random character each time
    return String((0..<length).map { _ in characters.randomElement()! })
}

func treeWithRandomNodes(count amount: Int) -> AVLTree {
    let tree = AVLTree()

    // Insert some random data into the tree
    for _ in 0..<amount {
        let randomScore = Double.random(in: 1...Double(amount * 2))
        let randomValue = buffer(randomAlphanumericString(length: Int(randomScore)))

        tree.insert(score: randomScore, member: randomValue)
    }

    return tree
}