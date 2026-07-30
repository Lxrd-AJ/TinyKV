import Foundation
import NIOCore

enum InsertResult {
    case added
    case updated
}

public final class SortedSet {
    // TODO: This class should delegate to `AVLTree` and `HashMap`. I need to use protocols in this class
    // so that for unit tests, I can mock out the tree & hashmap
    typealias KVPair = (member: ByteBuffer, score: Double)
    typealias AVLTreeType = (any BinarySearchTree<Double> & RangeQueries<Double>)
    typealias DictionaryType = (any Dictionary<Double>)
    
    internal let tree: AVLTreeType
    internal let hashmap: DictionaryType

    init(tree: AVLTreeType = AVLTree(), hashmap: DictionaryType = HashMap<Double>(capacity: 2)) {
        self.tree = tree
        self.hashmap = hashmap
    }

    @discardableResult
    func insert(member: ByteBuffer, with score: Double) -> InsertResult {
        if let oldScore = self.lookup(member) {
            if oldScore == score {
                return .updated
            }
            // Update it instead
            return self.update(member, replacing: oldScore, with: score)
        }

        tree.insert(score: score, member: member)
        hashmap.insert(key: member, value: score)
        return .added
    }

    func lookup(_ member: ByteBuffer) -> Double? {
        return self.hashmap.lookup(key: member)
    }

    func delete(_ member: ByteBuffer) -> Bool {
        guard let score = self.hashmap.lookup(key: member) else {
            return false
        }
        // Remove `member` from the hashmap and tree
        guard let _ = (try? self.hashmap.delete(key: member)) else {
            // If for some reason the deletion, ensure consistency in the internal state by returning
            // early.
            return false
        }
        let treeDidDelete = self.tree.delete(score: score, member: member)
        return treeDidDelete
    }

    // MARK: - Range and Rank

    // For ZRANK / ZREVRANK
    func rank(of member: ByteBuffer) -> Int? {
        // TODO:
        return nil
    }

    func range(from startRank: Int, to endRank: Int) -> [KVPair] {
        // TODO:
        return []
    }

    func range(from startScore: Double, to endScore: Double) -> [KVPair] {
        // TODO: 
        return []
    }

    func query(startingAt score: Double, member: ByteBuffer, offset: Int, limit: UInt = 100) -> [KVPair]{
        return self.tree.query(startingAt: (score, member), offset: offset, limit: limit)
    }
}

extension SortedSet {
    func update(_ member: ByteBuffer, replacing oldScore: Double, with newScore: Double) -> InsertResult {
        // hashmap insert would perform an upsert
        hashmap.insert(key: member, value: newScore)

        // The AVL Tree doesn't support upsert, so delete and re-insert with new value
        tree.delete(score: oldScore, member: member)
        tree.insert(score: newScore, member: member)
        
        return .updated
    }
}