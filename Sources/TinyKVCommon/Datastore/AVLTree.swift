import Foundation
import NIOCore

enum AVLTreeError: Error {
    case unexpectedMissingChildNode
}

final class AVLNode {
    var left: AVLNode?
    var right: AVLNode?
    // represent a leaf node with a default height of 1 and **not** 0
    private(set) var height: UInt8 = 1

    let score: Double
    let member: ByteBuffer

    init(score: Double, member: ByteBuffer) {
        self.score = score
        self.member = member
    }

    /// Tree updates are bottom-up, so a height change propagates from children to parents.
    func update() {
        self.height = 1 + max(self.left?.height ?? 0, self.right?.height ?? 0)
    }

    func balanceFactor() -> Int {
        return Int(self.left?.height ?? 0) - Int(self.right?.height ?? 0)
    }

    /// Compares this node against a target score and member.
    /// Returns:
    ///  -1 if this node is LESS than the target
    ///   1 if this node is GREATER than the target
    ///   0 if they are EXACTLY equal
    fileprivate func compares(toScore targetScore: Double, targetMember: ByteBuffer) -> Int {
        // 1. Primary Sort: Mathematical equivalence
        if self.score < targetScore { return -1 }
        if self.score > targetScore { return 1 }

         // 2. Secondary Sort: Lexicographical tie-breaker using our new Comparable conformance
        if self.member < targetMember { return -1 }
        if self.member > targetMember { return 1 }

        // 3. Perfect match
        return 0
    }
}

class AVLTree {
    var rootNode: AVLNode?

    func insert(score: Double, member: ByteBuffer) {
        // TODO:
    }
    
    func lookup(score: Double, member: ByteBuffer) -> AVLNode? {
        guard let node = self.treeSearch(from: self.rootNode, target: (score, member)) else {
            return nil
        }

        return node
    }
    
    func delete(score: Double, member: ByteBuffer) throws(TinyError) {
        guard let rootNode = self.rootNode else { throw TinyError.keyNotFound }
        self.rootNode = try treeDelete(from: rootNode, target: (score, member))
    }
}

extension AVLTree {
    typealias ReplacementNode = AVLNode

    private func treeSearch(from node: AVLNode?, target: (score: Double, member: ByteBuffer)) -> AVLNode? {
        // TODO:
        return nil
    }

    private func treeDelete(from: AVLNode, target: (score: Double, member: ByteBuffer)) throws(TinyError) -> ReplacementNode? {
        // TODO:
        return nil
    }
}

extension AVLTree {
    func balance(_ node: AVLNode) throws(AVLTreeError) -> ReplacementNode {
        let balanceFactor = node.balanceFactor()

        // Check if the node is left heavy and needs to be shifted to the right
        if balanceFactor > 1 {
            guard let leftChild = node.left else { throw .unexpectedMissingChildNode }
            
            // Check if it's a straight line chain and only a right rotation is needed
            if leftChild.balanceFactor() >= 0 {
                return try rotateRight(node)
            }
            // Check if it's a zig zag as we would need to perform a left rotation on `leftChild`
            // and a right rotation on `node`
            if leftChild.balanceFactor() < 0 {
                // Straighten the chain
                let newChildNode = try rotateLeft(leftChild)
                node.left = newChildNode;
                return try rotateRight(node)
            }

            // No need to worry about the 3rd case where a right & left child exist on `leftChild`
            // as that means `leftChild` is balanced.
        }

        // `node` is right heavy and needs to be rotated to the left
        if balanceFactor < -1 {
            guard let rightChild = node.right else { throw .unexpectedMissingChildNode }

            // Check if it's a straight line chain and only a left rotation on `node` is needed
            if rightChild.balanceFactor() <= 0 {
                return try rotateLeft(node)
            }
            // If it's a zig-zag, then rotate right `rightChild` then rotate left `node`
            if rightChild.balanceFactor() > 0 {
                // Straighten the chain
                let newChildNode = try rotateRight(rightChild)
                node.right = newChildNode
                return try rotateLeft(node)
            }

            // No need to worry about the 3rd case where a right & left child exist on `rightChild`
            // as that means `rightChild` is balanced.
        }

        return node
    }

    func rotateLeft(_ node: AVLNode) throws(AVLTreeError) -> ReplacementNode {
        guard let replacementNode = node.right else { 
            // This should only occur if the invariant of the AVL tree has been broken
            // i.e an insert operation happened and the tree was not re-balanced appropriately
            throw .unexpectedMissingChildNode 
        }
        let innerNode = replacementNode.left

        node.right = innerNode
        replacementNode.left = node

        // Update the node heights, respecting the call order as `height` depends on the child nodes
        node.update()
        replacementNode.update()

        return replacementNode
    }

    func rotateRight(_ node: AVLNode) throws(AVLTreeError) -> ReplacementNode {
        guard let replacementNode = node.left else {
            // This should only occur if the invariant of the AVL tree has been broken
            // i.e an insert operation happened and the tree was not re-balanced appropriately
            throw .unexpectedMissingChildNode
        }
        let innerNode = replacementNode.right

        replacementNode.right = node
        node.left = innerNode

        // Update the node heights, respecting the call order as `height` depends on the child nodes
        node.update()
        replacementNode.update()

        return replacementNode
    }
}