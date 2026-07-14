import Foundation
import NIO

/// A thread-safe (when used within an Actor) key-value store that supports progressive rehashing.
///
/// `HashMap` implements the Redis-style dictionary pattern where two hash tables are used
/// during a resize operation. Instead of blocking the entire server to move all keys at once,
/// keys are moved incrementally (progressively) during normal CRUD operations.
///
/// This ensures that the server maintains predictable latency even as the dataset grows
/// and triggers a resize.
class HashMap<Value>: Datastorage {
    /// The older hash table that is being migrated from during a rehash.
    /// This is `nil` when no rehashing is in progress.
    private(set) var oldHashTable: HashTable<Value>? 
    
    /// The newer, larger hash table that is being migrated to.
    /// If no rehashing is in progress, this is the primary and only table.
    private(set) var newerHashTable: HashTable<Value>
    
    /// The current index in the `oldHashTable` that is being migrated.
    /// This keeps track of progress so the next operation knows where to resume.
    private(set) var migrationIdx: UInt = 0

    /// Initializes a new HashMap with a starting capacity.
    /// - Parameter capacity: The initial number of buckets. Must be a power of 2.
    init(capacity: UInt) {
        self.newerHashTable = HashTable<Value>(capacity: Int(capacity))
    }

    func insert(key: ByteBuffer, value: Value) {
        // Insertion always goes to the newer hash table
        self.newerHashTable.insert(key: key, value: value)

        // Perform progressive resizing
        // If there isn't an older hashtable, check if one needs to be created
        if self.oldHashTable == nil {
            // Check if a resize is needed
            let sizeThreshold = self.newerHashTable.capacity * MAX_LOAD_FACTOR
            if self.newerHashTable.count >= sizeThreshold {
                self.triggerRehashing()
            }
        }

        // Migrate some keys regardless
        self.progressivelyRehash()
    }
    
    func lookup(key: ByteBuffer) -> Value? {
        self.progressivelyRehash()

        // Search both hash tables for the given `key`
        guard let item = self.newerHashTable.lookup(key: key) else {
            return self.oldHashTable?.lookup(key: key)
        }
        return item
    }
    
    /// Deletes a key-value pair from the storage.
    /// - Parameter key: The `ByteBuffer` containing the key.
    /// - Throws: `TinyError.keyNotFound` if the key does not exist.
    func delete(key: ByteBuffer) throws(TinyError) {
        self.progressivelyRehash()

        do{
            try self.newerHashTable.delete(key: key)

            // Prevent zombie keys by also checking if the key exists in the old hashtable
            // so that it is not zombie-fied by `progressiveRehash` moving it reviving it from the 
            // old hashtable into the newer one.
            if self.oldHashTable?.lookup(key: key) != nil {
                try self.oldHashTable!.delete(key: key)
            }
        }catch{
            guard let oldHashTable = self.oldHashTable else {
                throw .keyNotFound
            }

            try oldHashTable.delete(key: key)
        }

        // Prevent the edge case where this deletion potentially drains `self.oldHashTable`
        // as the guard statement in `progressivelyRehash` would prevent the cleanup of the old hashtable
        if self.oldHashTable?.count == 0 {
            self.cleanupOldHashTable()
        }
    }
}

extension HashMap {
    func triggerRehashing() {
        // Migrate the contents of the current hashtable `self.newerHashTable` to the older one
        // and create a new double-sized `self.newerHashTable`
        self.oldHashTable = self.newerHashTable
        self.newerHashTable = HashTable<Value>(capacity: self.oldHashTable!.capacity * 2)
        self.migrationIdx = 0
    }

    func progressivelyRehash() {
        guard let olderHashTable = self.oldHashTable, 
            olderHashTable.count > 0 else {
            return
        }

        // There is an older hashtable with items to be moved.
        // Move a fixed number of items from the old hash table to the new one
        var nwork = 0
        let MAX_EMPTY_BUCKET_VISITS = self.migrationIdx + UInt(AMOUNT_MIGRATION_WORK * 10)
        while 
            // Perform a fixed amount of work to prevent operations on the hashmap from stalling
            (nwork < AMOUNT_MIGRATION_WORK) && 
            (olderHashTable.count > 0) && 
            // Prevent out of bounds access which can happen if there still exists an item in a bucket location behind the `self.migrationIdx`
            (self.migrationIdx < olderHashTable.capacity) && 
            // To prevent a sparse `olderHashTable.buckets` from dominating the current operation
            // don't do more work past `MAX_EMPTY_BUCKET_VISITS`
            (self.migrationIdx < MAX_EMPTY_BUCKET_VISITS)
        {
            // Find the next empty slot
            let position = Int(self.migrationIdx)
            if let node = olderHashTable.buckets[position] {
                // Avoid overwriting new values if they already exist in the new hashtable
                if self.newerHashTable.lookup(key: node.pointee.key) == nil {
                    // Avoid using `newerHashTable.insert(_ newNodePtr: UnsafeMutablePointer<HashNode>)`
                    // as `node` would be deleted from the heap memory in a later call to `olderHashTable.delete(node)`
                    self.newerHashTable.insert(key: node.pointee.key, value: node.pointee.value)
                }

                // An error is not expected here as `node` is guaranteed to exist in the older 
                // hash table.
                try? olderHashTable.delete(key: node.pointee.key)
                nwork += 1
            }else{
                // Only move the migration index when the linked list at `migrationIdx` is empty
                self.migrationIdx += 1
            }
        }

        // Discard the old hashtable if we've completely migrated it.
        if olderHashTable.count == 0 {
            self.cleanupOldHashTable()
        }
    }
}

extension HashMap {
    private func cleanupOldHashTable() {
        // Once the local variable `olderHashTable` goes out of scope, the `self.oldHashTable`
        // would be garbage collected and it's `deinit` would handle the remaining cleanup
        self.oldHashTable = nil
    }
}