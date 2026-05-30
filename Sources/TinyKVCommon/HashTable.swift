import Foundation
import NIOCore

struct HashNode {
    // The hash value returned from the `hash` function. So that we don't have to perform
    // a re-hash `hash(key)` every time the hash table gets resized.
    let hashCode: Int
    let key: ByteBuffer
    var value: ByteBuffer
    var next: UnsafeMutablePointer<HashNode>?
}

class HashTable {
    // The buckets of the hash table. Each bucket is a linked list of `HashNode`s to handle collisions.
    // Store pointers to `HashNode`s instead of `HashNode`s directly to avoid unnecessary copying of the nodes when resizing the hash table.
    private(set) var buckets: UnsafeMutablePointer<UnsafeMutablePointer<HashNode>?>

    // The bit mask (size - 1)
    // The default module operator `index = hashCode % indexMask` is too slow on a CPU
    // Manipulating raw bits is faster, especially if the hash table size is a power of 2 as
    // `index = hashCode & indexMask` is extremely fast.
    private var indexMask: Int
    // The capacity of the hash table, which is always a power of 2.
    private let capacity: Int
    private(set) var count: Int

    init(capacity: Int) {
        let isPowerOfTwo = (capacity & (capacity - 1)) == 0
        precondition(capacity > 0 && isPowerOfTwo, "`capacity` must be a power of 2")

        self.indexMask = capacity - 1
        let ptr = calloc(capacity, MemoryLayout<UnsafeMutablePointer<HashNode>?>.stride)
        self.buckets = ptr!.bindMemory(to: UnsafeMutablePointer<HashNode>?.self, capacity: capacity)
        self.capacity = capacity
        self.count = 0
    }

    deinit {
        // Manually manage the heap memory
        for idx in 0..<capacity {
            if self.buckets[idx] != nil {
                var headNode = self.buckets[idx]
                repeat {
                    let nextNode = headNode?.pointee.next
                    HashTable.deallocateNode(with: headNode!)
                    headNode = nextNode
                } while headNode != nil
            }
        }

        free(self.buckets)
    }

    func insert(_ newNodePtr: UnsafeMutablePointer<HashNode>) {
        let idx = newNodePtr.pointee.hashCode & self.indexMask

        // 1. Traverse the existing bucket to check for an update
        var currentNode = self.buckets[idx]

        while let node = currentNode {
            // Fast path: Check hash code first, then the full string key
            if node.pointee.hashCode == newNodePtr.pointee.hashCode &&
               node.pointee.key == newNodePtr.pointee.key {

                // 2. We found a match! Update the value of the existing node.
                node.pointee.value = newNodePtr.pointee.value

                // 3. CRITICAL: We didn't use the newly allocated node because we 
                // just updated the existing one. We must deallocate the new node 
                // to prevent a memory leak.
                HashTable.deallocateNode(with: newNodePtr)

                // We are done updating, return early. Do not increment count.
                return
            }
            currentNode = node.pointee.next
        }

        // 4. If we reach here, the key does not exist in the table.
        // It's a true insert. Prepend to the linked list.
        if self.buckets[idx] != nil {
            newNodePtr.pointee.next = self.buckets[idx]
        }

        self.buckets[idx] = newNodePtr
        self.count += 1
    }

    func lookup(key: ByteBuffer) -> UnsafeMutablePointer<HashNode>? {
        guard count > 0 else {
            return nil
        }

        let idx = HashTable.hash(key) & self.indexMask
        var currentNode = self.buckets[idx]
        while let node = currentNode {
            if node.pointee.key == key {
                return node
            }
            currentNode = node.pointee.next
        }

        return nil
    }

    func delete(key: ByteBuffer) -> ByteBuffer? {
        return nil
    }
}

extension HashTable {
    static func allocateNode(key: ByteBuffer, value: ByteBuffer) -> UnsafeMutablePointer<HashNode> {
        let hashCode = HashTable.hash(key)
        let hashNode = HashNode(hashCode: hashCode, key: key, value: value)
        let ptr = UnsafeMutablePointer<HashNode>.allocate(capacity: 1)
        ptr.initialize(to: hashNode)

        return ptr
    }

    static func deallocateNode(with ptr: UnsafeMutablePointer<HashNode>) {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    /// Hash the key using the SipHash algorithm but modified to return only positive indices
    static func hash(_ key: ByteBuffer) -> Int {
        var hasher: Hasher = Hasher()
        hasher.combine(key)

        return hasher.finalize()
    }

    /// Convenience function for inserting an item into the hashtable
    func add(key: ByteBuffer, value: ByteBuffer) {
        self.insert(
            HashTable.allocateNode(key: key, value: value)
        )
    }
}