import Foundation
import NIOCore

/// A fixed-size hash table using separate chaining for collision resolution.
///
/// This implementation is inspired by Redis's `dictht` structure. It uses manual heap
/// allocation and raw pointers to minimize the overhead of Swift's ARC and to provide
/// predictable, low-level performance.
///
/// - Important: This class does not resize itself. It is intended to be managed by a
///   higher-level `HashMap` that orchestrates progressive rehashing between two instances.
class HashTable: Datastorage {
    /// The buckets of the hash table. Each bucket is a linked list of `HashNode`s.
    ///
    /// We store pointers to `HashNode`s to avoid unnecessary copying when moving nodes
    /// during migration or insertion. Memory is managed manually via `calloc` and `free`.
    private(set) var buckets: UnsafeMutablePointer<UnsafeMutablePointer<HashNode>?>

    /// The bit mask used for index calculation (capacity - 1).
    ///
    /// Since the capacity is always a power of 2, we use `hashCode & indexMask`
    /// instead of the modulo operator `%` for significantly faster indexing.
    private var indexMask: Int

    /// The fixed capacity of this hash table instance, which must be a power of 2.
    let capacity: Int

    /// The total number of elements currently stored in the table.
    private(set) var count: Int

    /// Initializes a new fixed-size hash table.
    ///
    /// - Parameter capacity: The number of buckets. Must be a power of 2.
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

    func insert(key: ByteBuffer, value: ByteBuffer) {
        self.insert(
            HashTable.allocateNode(key: key, value: value)
        )
    }

    func lookup(key: ByteBuffer) -> ByteBuffer? {
        guard count > 0 else {
            return nil
        }

        let keyHashCode = HashTable.hash(key)
        let idx = keyHashCode & self.indexMask
        var currentNode = self.buckets[idx]
        while let node = currentNode {
            if (keyHashCode == node.pointee.hashCode) && node.pointee.key == key {
                return node.pointee.value
            }
            currentNode = node.pointee.next
        }

        return nil
    }

    func delete(key: ByteBuffer) throws(TinyError) {
        func delete(_ node: UnsafeMutablePointer<HashNode>) {
            HashTable.deallocateNode(with: node)
            self.count -= 1
        }

        let keyHashCode = HashTable.hash(key)
        let idx = keyHashCode & self.indexMask

        guard let headNode = self.buckets[idx] else {
            throw TinyError.keyNotFound
        }

        if (keyHashCode == headNode.pointee.hashCode) && (headNode.pointee.key == key) {
            // The head of the linked list is the one to be deleted
            self.buckets[idx] = headNode.pointee.next
            delete(headNode)
            return
        }else {
            // The target node is **probably elsewhere in the linked list
            var previousNode = headNode
            var currentNode = previousNode.pointee.next
            while let thisNode = currentNode {
                if (keyHashCode == thisNode.pointee.hashCode) && (key == thisNode.pointee.key) {
                    previousNode.pointee.next = thisNode.pointee.next
                    delete(thisNode)
                    return
                }else{
                    currentNode = thisNode.pointee.next
                    previousNode = thisNode
                }
            }
        }

        throw TinyError.keyNotFound
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

    /// Hash the key using the SipHash algorithm 
    static func hash(_ key: ByteBuffer) -> Int {
        var hasher: Hasher = Hasher()
        hasher.combine(key)

        return hasher.finalize()
    }
}