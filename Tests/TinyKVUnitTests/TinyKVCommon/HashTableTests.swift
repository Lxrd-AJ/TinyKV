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
        hashTable.add(key: entry1.rawKey, value: entry1.rawValue)
        #expect(hashTable.count == 1)
        
        // Insert update
        let entry2 = KVPair(key: "test_key", value: "value_2", allocator: self.allocator)
        hashTable.add(key: entry2.rawKey, value: entry2.rawValue)
        
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
}

extension HashTableTests {
    private func insert(_ insertCount: Int, into hashTable: HashTable) {
        for i in 0..<insertCount {
            let pair = KVPair(key: "key_\(i)", value: "value_\(i)", allocator: self.allocator)
            hashTable.add(key: pair.rawKey, value: pair.rawValue)
        }
    }
}


struct KVPair {
    let key: String
    let value: String
    private(set) var rawKey: ByteBuffer
    private(set) var rawValue: ByteBuffer

    init(key: String, value: String, allocator: ByteBufferAllocator) {
        self.key = key
        self.value = value

        self.rawKey = allocator.buffer(capacity: 16)
        self.rawKey.writeString(key)
        self.rawValue = allocator.buffer(capacity: 16)
        self.rawValue.writeString(value)
    }
}