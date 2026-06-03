import Testing
import NIO
import Foundation
@testable import TinyKVCommon

struct HashMapUnitTests {
    
    struct lookup {
        @Test
        func testLookupKeyInNewerTable() {
            let hashMap = HashMap(capacity: 4)
            let key = ByteBuffer(string: "key1")
            let value = ByteBuffer(string: "value1")
            
            // TODO: (Replace) Manually insert into newerHashTable since HashMap.insert is not implemented yet
            hashMap.newerHashTable.add(key: key, value: value)
            
            let result = hashMap.lookup(key: key)
            #expect(result != nil)
            #expect(result?.pointee.value == value)
        }
        
        @Test
        func testLookupKeyInOldTableDuringRehash() {
            let hashMap = HashMap(capacity: 4)
            let key = ByteBuffer(string: "oldKey")
            let value = ByteBuffer(string: "oldValue")
            
            // Trigger rehashing to move current newerHashTable to oldHashTable
            // TODO: Recreate the triggering mechanism
            hashMap.triggerRehashing()
            
            // Manually insert into oldHashTable
            hashMap.oldHashTable?.add(key: key, value: value)
            
            let result = hashMap.lookup(key: key)
            #expect(result != nil)
            #expect(result?.pointee.value == value)
        }
        
        @Test
        func testLookupNonExistentKey() {
            let hashMap = HashMap(capacity: 4)
            let key = ByteBuffer(string: "missing")

            // TODO: Replace with insert method
            hashMap.newerHashTable.add(key: ByteBuffer(string: "<key1>"), value: ByteBuffer(string: "<value1>"))
            
            let result = hashMap.lookup(key: key)
            #expect(result == nil)
        }
        
        @Test
        func testLookupPrecedence() {
            let specimen = createSpecimen()
            let key = ByteBuffer(string: "commonKey")
            let oldValue = ByteBuffer(string: "oldValue")
            let newValue = ByteBuffer(string: "newValue")
            
            // Setup rehash state
            // TODO: Recreate the triggering mechanism
            specimen.triggerRehashing()
            
            // Add to both tables
            specimen.oldHashTable?.add(key: key, value: oldValue)
            specimen.newerHashTable.add(key: key, value: newValue)
            
            let result = specimen.lookup(key: key)
            #expect(result != nil)
            #expect(result?.pointee.value == newValue)
        }
    }
}

func createSpecimen(capacity: UInt = 8) -> HashMap {
    return HashMap(capacity: capacity)
}