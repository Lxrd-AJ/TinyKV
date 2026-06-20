import Testing
import NIOCore
@testable import TinyKVCommon

struct HashTableTests {
    let allocator = ByteBufferAllocator()

    @Test
    func testInitialization() {
        let hashTable = HashTable(capacity: 16)
        
        #expect(hashTable.count == 0)
    }

    @Test
    func testInsertSingleItem() {
        let hashTable = HashTable(capacity: 16)
        let actualKey = "test_key"
        let actualValue = "test_value"
        let entry = KVPair(key: actualKey, value: actualValue, allocator: self.allocator)
        
        let nodePtr = HashTable.allocateNode(key: entry.rawKey, value: entry.rawValue)
        hashTable.insert(nodePtr)
        
        #expect(hashTable.count == 1)
        
        let hashCode = HashTable.hash(entry.rawKey)
        let index = hashCode & 15 // capacity 16 - 1
        
        let expectedNodePtr = hashTable.buckets[index]
        #expect(expectedNodePtr?.pointee.next == nil, "There should only 1 item in the linked list")
        #expect(expectedNodePtr?.pointee.value == nodePtr.pointee.value, "Both nodes should point to the same object")
        #expect(expectedNodePtr?.pointee.value.getString(at: 0, length: entry.rawValue.readableBytes) == actualValue)
    }

    @Test
    func testInsertDuplicateItemUpdatesValue() {
        let hashTable = HashTable(capacity: 16)
        
        let entry1 = KVPair(key: "test_key", value: "value_1", allocator: self.allocator)
        hashTable.insert(key: entry1.rawKey, value: entry1.rawValue)
        #expect(hashTable.count == 1)
        
        // Insert update
        let entry2 = KVPair(key: "test_key", value: "value_2", allocator: self.allocator)
        hashTable.insert(key: entry2.rawKey, value: entry2.rawValue)
        
        // Count should remain the same
        #expect(hashTable.count == 1)
        
        let hashCode = HashTable.hash(entry2.rawKey)
        let index = hashCode & 15
        let expectedNodePtr = hashTable.buckets[index]
        #expect(expectedNodePtr?.pointee.value.getString(at: 0, length: entry2.rawValue.readableBytes) == "value_2")
    }

    @Test
    func testMultipleInserts() {
        let capacity = 32
        let hashTable = HashTable(capacity: capacity)
        let insertCount = 100
        
        for i in 0..<insertCount {
            let pair = KVPair(key: "key_\(i)", value: "value_\(i)", allocator: allocator)
            let nodePtr = HashTable.allocateNode(key: pair.rawKey, value: pair.rawValue)
            hashTable.insert(nodePtr)
        }
        
        #expect(hashTable.count == insertCount)
        
        // Verify a few items
        let testKeys = ["key_0", "key_50", "key_99"]
        for key in testKeys {
            var keyBuffer = allocator.buffer(capacity: 16)
            keyBuffer.writeString(key)
            let hashCode = HashTable.hash(keyBuffer)
            let index = hashCode & (capacity - 1)
            
            var currentNode = hashTable.buckets[index]
            var found = false
            while let node = currentNode {
                if node.pointee.key == keyBuffer {
                    found = true
                    break
                }
                currentNode = node.pointee.next
            }
            #expect(found, "Key \(key) was not found")
        }
    }

    @Test
    func testCollisionChaining() {
        let capacity = 4
        let hashTable = HashTable(capacity: capacity)
        
        // Insert enough items to guarantee a collision by Pigeonhole Principle
        for i in 0..<10 {
            let pair = KVPair(key: "key_\(i)", value: "val_\(i)", allocator: allocator)
            let nodePtr = HashTable.allocateNode(key: pair.rawKey, value: pair.rawValue)
            hashTable.insert(nodePtr)
        }
        
        #expect(hashTable.count == 10)
        
        // Verify that at least one bucket has a linked list with more than 1 node
        let maxChainLength = maxChainLength(for: hashTable)
        // Since we inserted 10 items into 4 buckets, the average chain length is 2.5
        // At least one bucket MUST have a chain length >= 3
        #expect(maxChainLength >= 3, "Expected at least one collision chain of length >= 3")
    }

    @Test
    func freesMemoryOnDeletion() throws {
        weak var weakHashTable: HashTable?
        
        do {
            let capacity = 32
            let hashTable = HashTable(capacity: capacity)
            weakHashTable = hashTable
            
            let insertCount = 100
            
            for i in 0..<insertCount {
                let pair = KVPair(key: "key_\(i)", value: "value_\(i)", allocator: allocator)
                let nodePtr = HashTable.allocateNode(key: pair.rawKey, value: pair.rawValue)
                hashTable.insert(nodePtr)
            }

            #expect(hashTable.count == insertCount)
        }
        
        #expect(weakHashTable == nil, "HashTable leaked memory: instance was not deallocated")
    }

    @Test 
    func canLookupItems() throws {
        let hashTable = HashTable(capacity: 32)
        let numItemsToAdd = 64
        self.insert(numItemsToAdd, into: hashTable)

        let randomKeyIndicesToLookup = (0..<5).map({ _ in Int.random(in: 0..<64) })
        for randIdx in randomKeyIndicesToLookup {
            let key = "key_\(randIdx)"
            var keyBuffer = allocator.buffer(capacity: 16)
            keyBuffer.writeString(key)
            let returnedNodePtr = hashTable.lookup(key: keyBuffer)

            #expect(returnedNodePtr != nil, "The returned node should not be empty")
            #expect(returnedNodePtr?.pointee.value.getString(at: 0, length: returnedNodePtr!.pointee.value.readableBytes) == "value_\(randIdx)")
        }
    }

    struct Deletion {
        let allocator = ByteBufferAllocator()

        @Test 
        func canDeleteNodeAtLinkedListHead() throws {
            let capacity = 64
            let specimen = HashTable(capacity: capacity)
            let entries = TinyKVUnitTests.insert(1, into: specimen, using: self.allocator)
            #expect(maxChainLength(for: specimen) == 1, "There should be no collisions")

            let entry = entries[0]
            let expectedIdx = HashTable.hash(entry.rawKey) & (capacity - 1)
            try specimen.delete(key: entry.rawKey)

            #expect(specimen.count == 0)
            #expect(specimen.buckets[expectedIdx] == nil)
            #expect(specimen.lookup(key: entry.rawKey) == nil)
            verifyAllBucketsAreNil(hashTable: specimen)
        }

        @Test 
        func canDeleteNodeNestedInLinkedList() throws {
            let capacity = 8
            let numInsertions = 64
            let specimen = HashTable(capacity: capacity)
            // Ensure there are collisions in this hash table
            let entries = TinyKVUnitTests.insert(numInsertions, into: specimen, using: self.allocator)

            let entry1 = entries[9]
            try specimen.delete(key: entry1.rawKey)
            #expect(specimen.count == (numInsertions - 1))
            #expect(specimen.lookup(key: entry1.rawKey) == nil, "The element should have been deleted")

            let entry2 = entries[32]
            try specimen.delete(key: entry2.rawKey)
            #expect(specimen.count == (numInsertions - 2))
            #expect(specimen.lookup(key: entry2.rawKey) == nil, "The element should have been deleted")
        }

        @Test 
        func canDeleteNodeAtLinkedListTail() throws {
            let capacity = 8
            let numInsertions = 64
            let specimen = HashTable(capacity: capacity)
            let entries = TinyKVUnitTests.insert(numInsertions, into: specimen, using: self.allocator)

            // Because inserts are prepended, the very first item inserted
            // will be pushed to the tail of whichever bucket it lands in.
            let targetTailEntry = entries[0]
            let expectedIdx = HashTable.hash(targetTailEntry.rawKey) & (capacity - 1)

            // Verify that the chain actually has multiple nodes so we are truly deleting a tail
            var initialChainLength = 0
            var currentNode = specimen.buckets[expectedIdx]
            while let node = currentNode {
                initialChainLength += 1
                currentNode = node.pointee.next
            }
            #expect(initialChainLength > 1, "The target bucket must have more than 1 item to test tail deletion")

            // Perform the deletion
            try specimen.delete(key: targetTailEntry.rawKey)

            // Verify the global count decreased
            #expect(specimen.count == (numInsertions - 1))
            
            // Verify the item is actually gone
            #expect(specimen.lookup(key: targetTailEntry.rawKey) == nil, "The element should have been deleted")

            // Verify the chain length of that specific bucket decreased by exactly 1
            var finalChainLength = 0
            currentNode = specimen.buckets[expectedIdx]
            while let node = currentNode {
                finalChainLength += 1
                currentNode = node.pointee.next
            }
            #expect(finalChainLength == (initialChainLength - 1), "The bucket's chain length should have decreased by exactly 1")
        }

        @Test 
        func errorsWhenNodeNotFound() {
            let capacity = 8
            let specimen = HashTable(capacity: capacity)

            var key = self.allocator.buffer(capacity: 8)
            key.writeString("<dummyKey>")

            #expect(throws: TinyError.keyNotFound) {
                try specimen.delete(key: key)
            }

            TinyKVUnitTests.insert(64, into: specimen, using: self.allocator)
            #expect(throws: TinyError.keyNotFound, performing: {
                try specimen.delete(key: key)
            })
        }
    }
}

extension HashTableTests {
    @discardableResult
    private func insert(_ insertCount: Int, into hashTable: HashTable) -> [KVPair] {
        return TinyKVUnitTests.insert(insertCount, into: hashTable, using: self.allocator)
    }
}

func maxChainLength(for hashTable: HashTable) -> Int {
    // Verify that at least one bucket has a linked list with more than 1 node
    var maxChainLength = 0
    for i in 0..<hashTable.capacity {
        var chainLength = 0
        var currentNode = hashTable.buckets[i]
        while let node = currentNode {
            chainLength += 1
            currentNode = node.pointee.next
        }
        maxChainLength = max(maxChainLength, chainLength)
    }

    return maxChainLength
}

func verifyAllBucketsAreNil(hashTable: HashTable) {
    for idx in 0..<hashTable.capacity {
        #expect(hashTable.buckets[idx] == nil, "Bucket \(idx) should be empty")
    }
}
