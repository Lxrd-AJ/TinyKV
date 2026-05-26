import Foundation
import NIOCore

struct HashNode {
    let key: String
    // The hash value returned from the `hash` function. So that we don't have to perform
    // a re-hash `hash(key)` every time the hash table gets resized.
    let hashCode: Int
    var value: ByteBuffer
    var next: UnsafeMutablePointer<HashNode>?
}

public struct HashTable {
    // The buckets of the hash table. Each bucket is a linked list of `HashNode`s to handle collisions.
    // Store pointers to `HashNode`s instead of `HashNode`s directly to avoid unnecessary copying of the nodes when resizing the hash table.
    var buckets: UnsafeMutablePointer<UnsafeMutablePointer<HashNode>?>?

    // The bit mask (size - 1)
    // The default module operator `index = hashCode % indexMask` is too slow on a CPU
    // Manipulating raw bits is faster, especially if the hash table size is a power of 2 as
    // `index = hashCode & indexMask` is extremely fast.
    private var indexMask: Int

    private let capacity: Int
    private(set) var count: Int

    public init(capacity: Int) {
        let isPowerOfTwo = (capacity & (capacity - 1)) == 0
        precondition(capacity > 0 && isPowerOfTwo, "`capacity` must be a power of 2")

        self.indexMask = capacity - 1
        let ptr = calloc(capacity, MemoryLayout<UnsafeMutablePointer<HashNode>?>.stride)
        self.buckets = ptr?.bindMemory(to: UnsafeMutablePointer<HashNode>?.self, capacity: capacity)
        self.capacity = capacity
        self.count = 0
    }


    /// Hash the key using the SipHash algorithm but modified to return only positive indices
    func hash(key: String) -> Int {
        var hasher: Hasher = Hasher()
        hasher.combine(key)

        return hasher.finalize()
    }
}