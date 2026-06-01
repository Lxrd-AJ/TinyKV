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
class HashMap: Datastorage {
    /// The older hash table that is being migrated from during a rehash.
    /// This is `nil` when no rehashing is in progress.
    private(set) var oldHashTable: HashTable? 
    
    /// The newer, larger hash table that is being migrated to.
    /// If no rehashing is in progress, this is the primary and only table.
    private(set) var newerHashTable: HashTable
    
    /// The current index in the `oldHashTable` that is being migrated.
    /// This keeps track of progress so the next operation knows where to resume.
    private(set) var migrationIdx: UInt = 0

    /// Initializes a new HashMap with a starting capacity.
    /// - Parameter capacity: The initial number of buckets. Must be a power of 2.
    init(capacity: UInt) {
        self.newerHashTable = HashTable(capacity: Int(capacity))
    }

    func insert(_ newNodePtr: UnsafeMutablePointer<HashNode>) {
        // TODO:
    }
    
    func lookup(key: ByteBuffer) -> UnsafeMutablePointer<HashNode>? {
        // TODO:
        return nil
    }
    
    /// Deletes a key-value pair from the storage.
    /// - Parameter key: The `ByteBuffer` containing the key.
    /// - Throws: `TinyError.keyNotFound` if the key does not exist.
    func delete(key: ByteBuffer) throws(TinyError) {
        // TODO
    }
}