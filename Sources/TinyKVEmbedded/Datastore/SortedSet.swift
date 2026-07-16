import Foundation
import NIOCore

enum InsertResult {
    case added
    case updated
}

public final class SortedSet {
    internal let tree: AVLTree = AVLTree()
    internal let hashmap: HashMap<Double> = HashMap<Double>(capacity: 2)

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

    // For ZRANGE / ZREVRANGE
    func range(from startRank: Int, to endRank: Int) -> [(member: ByteBuffer, score: Double)] {
        // TODO:
        return []
    }

    // For ZRANGEBYSCORE
    func range(from startScore: Double, to endScore: Double) -> [(member: ByteBuffer, score: Double)] {
        // TODO: 
        return []
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