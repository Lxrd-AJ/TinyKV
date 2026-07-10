import Testing
import NIO
import Foundation
@testable import TinyKVEmbedded

struct HashMapUnitTests {
    
    struct lookup {
        @Test
        func testLookupKeyInNewerTable() {
            let hashMap = HashMap(capacity: 4)
            let key = ByteBuffer(string: "key1")
            let value = ByteBuffer(string: "value1")
            
            hashMap.insert(key: key, value: value)
            
            let result = hashMap.lookup(key: key)
            #expect(result != nil)
            #expect(result == value)
        }
        
        @Test
        func testLookupKeyInOldTableDuringRehash() {
            let hashMap = HashMap(capacity: 32)
            let key = ByteBuffer(string: "oldKey")
            let value = ByteBuffer(string: "oldValue")
            
            hashMap.insert(key: key, value: value)
            // Trigger rehashing to move current newerHashTable to oldHashTable
            hashMap.triggerRehashing()
            
            let result = hashMap.lookup(key: key)
            #expect(result != nil)
            #expect(result == value)
        }
        
        @Test
        func testLookupNonExistentKey() {
            let hashMap = HashMap(capacity: 4)
            let key = ByteBuffer(string: "missing")

            hashMap.insert(key: ByteBuffer(string: "<key1>"), value: ByteBuffer(string: "<value1>"))
            
            let result = hashMap.lookup(key: key)
            #expect(result == nil)
        }
        
        @Test
        func testLookupPrecedence() {
            let specimen = createSpecimen()
            let key = ByteBuffer(string: "commonKey")
            let oldValue = ByteBuffer(string: "oldValue")
            let newValue = ByteBuffer(string: "newValue")
            
            // Setup rehash state by first inserting the old value
            specimen.insert(key: key, value: oldValue)
            specimen.triggerRehashing()
            // insert to newer table
            specimen.insert(key: key, value: newValue)
            
            let result = specimen.lookup(key: key)
            #expect(result != nil)
            #expect(result == newValue, 
                "'\(result!.getString(at: 0, length: oldValue.readableBytes) ?? "")' should be equal to '\(newValue.getString(at:0, length: newValue.readableBytes) ?? "")'"
            )
        }
    }

    struct delete {
        @Test
        func testDeleteKeyInNewerTable() throws {
            let specimen = createSpecimen()
            let key = ByteBuffer(string: "key1")
            
            specimen.insert(key: key, value: ByteBuffer(string: "value1"))
            
            // Verify it exists before deletion
            #expect(specimen.lookup(key: key) != nil)
            
            try specimen.delete(key: key)
            
            // Verify it is gone
            #expect(specimen.lookup(key: key) == nil)
        }
        
        @Test
        func deleteKeyInOldTableDuringRehash() throws {
            let specimen = createSpecimen(capacity: 32)
            let key = ByteBuffer(string: "oldKey")
            
            // capacity should be 32*8 so rehashing should not have been triggered
            #expect(130 < specimen.newerHashTable.capacity * MAX_LOAD_FACTOR, "Sanity check")
            TinyKVUnitTests.insert(130, into: specimen)
            // Explicitly trigger it
            specimen.triggerRehashing()
            // Calling `lookup` should move some items to the newerHashTable -> drains `AMOUNT_MIGRATION_WORK: Int = 124` items
            #expect(specimen.lookup(key: key) == nil)
            // Ensure that `key` is in the old hash table
            specimen.oldHashTable!.insert(key: key, value: ByteBuffer(string: "oldValue"))

            // Verify that `key` is deleted from the old hashtable
            // This would also drain from the old hastable
            try specimen.delete(key: key)
            
            #expect(specimen.lookup(key: key) == nil)
            #expect(
                specimen.newerHashTable.count == 130 && specimen.oldHashTable == nil, 
                "The old hashtable should be fully drained"
            )
        }
        
        @Test
        func testDeleteNonExistentKey() {
            let specimen = createSpecimen(capacity: 32)
            let key = ByteBuffer(string: "missing")
            
            #expect(throws: TinyError.keyNotFound) {
                try specimen.delete(key: key)
            }

            // Insert some dummy items
            specimen.insert(key: ByteBuffer(string: "<key2>"), value: ByteBuffer(string: "oldValue"))
            TinyKVUnitTests.insert(130, into: specimen)
            specimen.triggerRehashing()
            specimen.insert(key: ByteBuffer(string: "<key1>"), value: ByteBuffer(string: "value1"))

            #expect(throws: TinyError.keyNotFound) {
                try specimen.delete(key: key)
            }
        }

        @Test
        func safelyDeleteKeyInBothNewAndOldHashTableDuringProgressiveRehashing() throws {
            let specimen = createSpecimen(capacity: 32);
            let entry = KVPair(key: "<targetKey>", value: "<newValue>")

            // Trigger progressive rehashing
            TinyKVUnitTests.insert(32 * MAX_LOAD_FACTOR, into: specimen)
            // drains 128 items from old hashtable
            specimen.insert(key: entry.rawKey, value: entry.rawValue) 
            // Ensure that the key now exists in both new and old hash table
            specimen.oldHashTable!.insert(key: entry.rawKey, value: entry.rawValue)

            // Verify that deleting the entry from specimen does not create a zombie key eventually
            try specimen.delete(key: entry.rawKey)
            #expect(specimen.lookup(key: entry.rawKey) == nil, "The key should have been deleted from both the new and old hashtable")
        }
    }

    struct insert {
        @Test
        func insertUsesNewHashTable() throws {
            let specimen = createSpecimen()
            let entry = KVPair(key: "<key1>", value: "<value1>")

            specimen.insert(key: entry.rawKey, value: entry.rawValue)

            // Verify that the newer hashtable was used
            #expect(specimen.newerHashTable.lookup(key: entry.rawKey) != nil)
            #expect(specimen.oldHashTable == nil)
        }

        @Test func insertUsesNewHashTableDuringMigration() throws {
            let capacity: UInt = 32
            let specimen = createSpecimen(capacity: capacity)
            // We want to trigger rehashing, but not finish it immediately.
            // Rehashing is triggered when count reaches capacity * MAX_LOAD_FACTOR.
            // A single step of progressive rehashing migrates AMOUNT_MIGRATION_WORK items.
            // For capacity 32 and MAX_LOAD_FACTOR 8, threshold is 256.
            // 256 > 124 * 2 (248), so oldHashTable will survive 2 insertions after rehashing starts.
            let numItems = Int(capacity) * MAX_LOAD_FACTOR
            let entry = KVPair(key: "<key>", value: "<value>")

            // This should trigger progressive rehashing on the last insertion, 
            // and perform the first step of migration
            let _ = TinyKVUnitTests.insert(numItems, into: specimen)

            // Finally -- insert `entry` which will perform a second step of migration
            specimen.insert(key: entry.rawKey, value: entry.rawValue)

            #expect(specimen.newerHashTable.lookup(key: entry.rawKey) != nil)
            #expect(specimen.oldHashTable != nil, "Progressive rehashing should have been triggered but not finished")
            #expect(specimen.oldHashTable!.lookup(key: entry.rawKey) == nil)
        }
    }

    struct rehashing {
        @Test func progressiveRehashingSteps() throws {
            let capacity: UInt = 32
            let specimen = createSpecimen(capacity: capacity)
            // threshold = 32 * 8 = 256
            // AMOUNT_MIGRATION_WORK = 124
            
            // Insert 255 items, no rehashing yet
            let _ = TinyKVUnitTests.insert(255, into: specimen)
            #expect(specimen.oldHashTable == nil)
            
            // Insert 256th item. Triggers rehashing, migrates 124 items.
            // oldHashTable count = 256 - 124 = 132.
            let k256 = KVPair(key: "custom_key_256", value: "value")
            specimen.insert(key: k256.rawKey, value: k256.rawValue)
            #expect(specimen.oldHashTable != nil)
            #expect(specimen.oldHashTable?.count == 132)
            #expect(specimen.migrationIdx > 0)
            
            // Insert 257th item. Migrates another 124 items.
            // oldHashTable count = 132 - 124 = 8.
            let k257 = KVPair(key: "custom_key_257", value: "value")
            specimen.insert(key: k257.rawKey, value: k257.rawValue)
            #expect(specimen.oldHashTable != nil)
            #expect(specimen.oldHashTable?.count == 8)
            
            // Insert 258th item. Migrates the remaining 8 items.
            // oldHashTable should be nil now.
            let k258 = KVPair(key: "custom_key_258", value: "value")
            specimen.insert(key: k258.rawKey, value: k258.rawValue)
            #expect(specimen.oldHashTable == nil)
            #expect(specimen.newerHashTable.count == 258)
        }
    }
}

func createSpecimen(capacity: UInt = 8) -> HashMap {
    return HashMap(capacity: capacity)
}