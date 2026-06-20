import Foundation
import NIO

/// A single entry in the `HashTable`.
///
/// This structure mirrors a C-style linked list node used for collision handling.
/// It stores a pre-computed hash code to avoid expensive re-hashing during table resizes.
struct HashNode {
    /// The hash value returned from the `hash` function.
    /// Stored to ensure that resizing the hash table only requires bitwise operations
    /// rather than re-calculating the hash for every key.
    let hashCode: Int
    /// The key stored in this node.
    let key: ByteBuffer
    /// The value associated with the key.
    var value: ByteBuffer
    /// Pointer to the next node in the bucket (collision chain).
    var next: UnsafeMutablePointer<HashNode>?
}

/// A protocol defining the core operations for a key-value storage engine.
protocol Datastorage {
    /// Inserts a new node into the storage.
    /// - Parameter key: The `ByteBuffer` containing the key.
    /// - Parameter value: The `ByteBuffer` containing the value.
    func insert(key: ByteBuffer, value: ByteBuffer)
    
    /// Looks up a value by its key.
    /// - Parameter key: The `ByteBuffer` containing the key.
    /// - Returns: A pointer to the `HashNode` if found, otherwise `nil`.
    func lookup(key: ByteBuffer) -> UnsafeMutablePointer<HashNode>?
    
    /// Deletes a key-value pair from the storage.
    /// - Parameter key: The `ByteBuffer` containing the key.
    /// - Throws: `TinyError.keyNotFound` if the key does not exist.
    func delete(key: ByteBuffer) throws(TinyError)
}