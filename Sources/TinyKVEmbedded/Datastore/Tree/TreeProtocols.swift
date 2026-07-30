import Foundation
import NIOCore

protocol BinarySearchTree<Score> {
    associatedtype Score: Comparable

    func insert(score: Score, member: ByteBuffer)
    func lookup(score: Score, member: ByteBuffer) -> Bool 
    @discardableResult
    func delete(score: Score, member: ByteBuffer) -> Bool
}

protocol RangeQueries<Score> {
    associatedtype Score: Comparable

    func query(startingAt: (score: Score, member: ByteBuffer), offset: Int, limit: UInt) -> [(member: ByteBuffer, score: Score)]
}