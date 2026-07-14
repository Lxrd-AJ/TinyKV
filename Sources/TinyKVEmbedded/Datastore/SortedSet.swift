import Foundation
import NIOCore

enum InsertResult {
    case added
    case updated
}

final class SortedSet {
    private let tree: AVLTree = AVLTree()
    private let hashmap: HashMap<Double> = HashMap<Double>(capacity: 2)

    func insert(member: ByteBuffer, with score: Double) -> InsertResult {
        // TODO: Implement
        return .added
    }

    func lookup(_ member: ByteBuffer) -> Double? {
        // TODO
        return nil
    }

    func delete(_ member: ByteBuffer) -> Bool {
        // TODO: Implement
        return false
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