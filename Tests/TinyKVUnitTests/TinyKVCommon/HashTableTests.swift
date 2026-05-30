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
        let actualValue = "test_value"
        var buffer = allocator.buffer(capacity: 16)
        buffer.writeString(actualValue)
        
        let nodePtr = HashTable.allocateNode(key: "test_key", value: buffer)
        hashTable.insert(nodePtr)
        
        #expect(hashTable.count == 1)
        
        let hashCode = HashTable.hash("test_key")
        let index = hashCode & 15 // capacity 16 - 1
        
        let expectedNodePtr = hashTable.buckets[index]
        #expect(expectedNodePtr?.pointee.next == nil, "There should only 1 item in the linked list")
        #expect(expectedNodePtr?.pointee.value == nodePtr.pointee.value, "Both nodes should point to the same object")
        #expect(expectedNodePtr?.pointee.value.getString(at: 0, length: buffer.readableBytes) == actualValue)
    }

    @Test
    func testInsertDuplicateItemUpdatesValue() {
        let hashTable = HashTable(capacity: 16)
        
        // Insert first
        var buffer1 = allocator.buffer(capacity: 16)
        buffer1.writeString("value_1")
        let nodePtr1 = HashTable.allocateNode(key: "test_key", value: buffer1)
        hashTable.insert(nodePtr1)
        
        #expect(hashTable.count == 1)
        
        // Insert update
        var buffer2 = allocator.buffer(capacity: 16)
        buffer2.writeString("value_2")
        let nodePtr2 = HashTable.allocateNode(key: "test_key", value: buffer2)
        hashTable.insert(nodePtr2)
        
        // Count should remain the same
        #expect(hashTable.count == 1)
        
        let hashCode = HashTable.hash("test_key")
        let index = hashCode & 15
        let expectedNodePtr = hashTable.buckets[index]
        #expect(expectedNodePtr?.pointee.value.getString(at: 0, length: buffer2.readableBytes) == "value_2")
    }

    @Test
    func testMultipleInserts() {
        let capacity = 32
        let hashTable = HashTable(capacity: capacity)
        let insertCount = 100
        
        for i in 0..<insertCount {
            var buffer = allocator.buffer(capacity: 16)
            buffer.writeString("value_\(i)")
            let nodePtr = HashTable.allocateNode(key: "key_\(i)", value: buffer)
            hashTable.insert(nodePtr)
        }
        
        #expect(hashTable.count == insertCount)
        
        // Verify a few items
        let testKeys = ["key_0", "key_50", "key_99"]
        for key in testKeys {
            let hashCode = HashTable.hash(key)
            let index = hashCode & (capacity - 1)
            
            var currentNode = hashTable.buckets[index]
            var found = false
            while let node = currentNode {
                if node.pointee.key == key {
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
            var buffer = allocator.buffer(capacity: 16)
            buffer.writeString("val_\(i)")
            let nodePtr = HashTable.allocateNode(key: "key_\(i)", value: buffer)
            hashTable.insert(nodePtr)
        }
        
        #expect(hashTable.count == 10)
        
        // Verify that at least one bucket has a linked list with more than 1 node
        var maxChainLength = 0
        for i in 0..<capacity {
            var chainLength = 0
            var currentNode = hashTable.buckets[i]
            while let node = currentNode {
                chainLength += 1
                currentNode = node.pointee.next
            }
            maxChainLength = max(maxChainLength, chainLength)
        }
        
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
                var buffer = allocator.buffer(capacity: 16)
                buffer.writeString("value_\(i)")
                let nodePtr = HashTable.allocateNode(key: "key_\(i)", value: buffer)
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
            let returnedNodePtr = hashTable.lookup(key: key)

            #expect(returnedNodePtr != nil, "The returned node should not be empty")
            #expect(returnedNodePtr?.pointee.value.getString(at: 0, length: returnedNodePtr!.pointee.value.readableBytes) == "value_\(randIdx)")
        }
    }
}

extension HashTableTests {
    private func insert(_ insertCount: Int, into hashTable: HashTable) {
        for i in 0..<insertCount {
            var buffer = self.allocator.buffer(capacity: 16)
            buffer.writeString("value_\(i)")
            hashTable.add(key: "key_\(i)", value: buffer)
        }
    }
}
