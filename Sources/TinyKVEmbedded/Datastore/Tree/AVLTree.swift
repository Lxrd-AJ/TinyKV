import Foundation
import NIOCore

enum AVLTreeError: Error {
    case unexpectedMissingChildNode
    case keyNotFound
}

final class AVLNode {
    var left: AVLNode?
    var right: AVLNode?
    // represent a leaf node with a default height of 1 and **not** 0
    private(set) var height: UInt8 = 1
    // The number of nodes in the subtree - This helps support ordered statistics tree operations
    private(set) var size: UInt = 1

    let score: Double
    let member: ByteBuffer

    init(score: Double, member: ByteBuffer) {
        self.score = score
        self.member = member
    }

    /// Tree updates are bottom-up, so a height change propagates from children to parents.
    func update() {
        self.height = 1 + max(self.left?.height ?? 0, self.right?.height ?? 0)
        self.size = (self.left?.size ?? 0) + (self.right?.size ?? 0) + 1
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

         // 2. Secondary Sort: Lexicographical tie-breaker using our `ByteBuffer`'s Comparable conformance
        if self.member < targetMember { return -1 }
        if self.member > targetMember { return 1 }

        // 3. Perfect match
        return 0
    }
}

class AVLTree {
    private(set) var rootNode: AVLNode?

    func insert(score: Double, member: ByteBuffer) {
        precondition(!score.isNaN, "AVLTree invariants require valid numeric scores.")
        self.rootNode = treeInsert(into: self.rootNode, target: (score, member))
    }
    
    func lookup(score: Double, member: ByteBuffer) -> Bool {
        precondition(!score.isNaN, "AVLTree invariants require valid numeric scores.")
        guard let _ = treeSearch(from: self.rootNode, for: score, and: member) else {
            return false
        }

        return true
    }
    
    @discardableResult
    func delete(score: Double, member: ByteBuffer) -> Bool {
        precondition(!score.isNaN, "AVLTree invariants require valid numeric scores.")
        do {
            self.rootNode = try treeDelete(from: self.rootNode, target: (score, member))
            return true
        } catch {
            return false
        }
    }

    func iterator(from target: (score: Double, member: ByteBuffer)? = nil) -> AVLTreeIterator {
        return AVLTreeIterator(self.rootNode, startingFrom: target)
    }
}

// Support range queries on the tree
extension AVLTree {
    // For ZQUERY key score name offset limit
    func query(startingAt score: Double, member: ByteBuffer, offset: Int, limit: UInt = 100) -> [KVPair]{
        guard let rootNode = self.rootNode else { return [] }
        var iterator = AVLTreeIterator(rootNode, startingFrom: (score, member))
        
        // TODO: Continue here -- Rewrite this using ordered statistics tree
        
        // Traverse by offset steps.
        let _ = (0..<abs(offset)).map({ _ in iterator.next() })

        // 3. Collect up to  limit  elements into your  [KVPair]  array.
        return (0..<limit)
            .compactMap({ _ in iterator.next() })
            .map({ node in return (node.member, node.score)})
    }
}

extension AVLTree {
    typealias ReplacementNode = AVLNode

    /// Recursive tree insertion
    private func treeInsert(into node: AVLNode?, target: (score: Double, member: ByteBuffer)) -> AVLNode {
        // Handle the base case where we've found an empty slot to insert the new entry
        guard var node = node else {
            return AVLNode(score: target.score, member: target.member)
        }

        // Handle the descent down the call stack
        let comparison = node.compares(toScore: target.score, targetMember: target.member)
        if comparison > 0 {
            // The target needs to be inserted in the left subtree as it is smaller than `node`
            let leftSubtree = treeInsert(into: node.left, target: target)
            node.left = leftSubtree
        }else if comparison < 0 {
            // `target` needs to go in the right subtree
            let rightSubtree = treeInsert(into: node.right, target: target)
            node.right = rightSubtree
        }else{
            // `node` and target are the same, perform no operation
            return node
        }

        node.update()
        node = try! balance(node)
        return node
    }

    private func treeDelete(from: AVLNode?, target: (score: Double, member: ByteBuffer)) throws(AVLTreeError) -> ReplacementNode? {
        guard let node = from else {
            // We've reached the leaf of the tree and still haven't found the node
            throw AVLTreeError.keyNotFound
        }

        let comparison = node.compares(toScore: target.score, targetMember: target.member)
        if comparison > 0 { // the target must be in the left sub-tree
            node.left = try treeDelete(from: node.left, target: target)
            node.update()
            return try! balance(node)
        }else if comparison < 0 {
            // `target` must be in the right subtree
            node.right = try treeDelete(from: node.right, target: target)
            node.update()
            return try! balance(node)
        }else{
            // We've found the node `node` to be deleted
            if node.left == nil || node.right == nil {
                // case 1: no children at all or at most 1 child exists
                return node.left == nil ? node.right : node.left
            }else{
                // case 2: `node` has 2 children and it's replacement should be it's next in order
                // successor.
                // Traverse down the tree to find it's successor
                var successor = node.right!
                while successor.left != nil {
                    successor = successor.left!
                }
                
                // Safely delete the successor from the right subtree FIRST!
                let newRight = try treeDelete(from: node.right, target: (successor.score, successor.member))
                
                // Now that it's detached, it's safe to rewire its pointers
                successor.left = node.left
                successor.right = newRight
                
                // Unlink `node` from the tree
                node.left = nil
                node.right = nil

                // Ensure `successor` is compliant before returning it
                successor.update()
                return try balance(successor)
            }
        }
    }
}

// MARK: - Tree/Balancing

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

// MARK: - Pretty Print
extension AVLTree {
    func prettyPrint() {
        guard let root = rootNode else {
            print("Empty tree")
            return
        }
        printNode(root, prefix: "", isLeft: nil)
    }

    private func printNode(_ node: AVLNode?, prefix: String, isLeft: Bool?) {
        guard let node = node else { return }

        let rightPrefix = prefix + (isLeft == true ? "│   " : "    ")
        printNode(node.right, prefix: rightPrefix, isLeft: false)

        let memberStr = String(buffer: node.member)
        let branch = isLeft == nil ? "" : (isLeft == true ? "└── " : "┌── ")
        print("\(prefix)\(branch)\(node.score):\(memberStr) (h:\(node.height); bf:\(node.balanceFactor()); s:\(node.size))")

        let leftPrefix = prefix + (isLeft == false ? "│   " : "    ")
        printNode(node.left, prefix: leftPrefix, isLeft: true)
    }
}

// MARK: - Tree/Ordered Statistics Tree
extension AVLTree {
    /// Returns the 0-based index of the target (or the index of its lower-bound if it doesn't exist)
    func rank(of target: (score: Double, member: ByteBuffer)) -> UInt {
        var currentNode = self.rootNode
        var rankCount: UInt = 0

        while let node = currentNode {
            let cmp = node.compares(toScore: target.score, targetMember: target.member)

            if cmp < 0 {
                // `target` is larger, continue searching in the right subtree
                // Tally the skipped left subtree and current node to `rankCount`
                rankCount += (node.left?.size ?? 0) + 1
                currentNode = node.right
            } else if cmp > 0 {
                // `target` is smaller than `currentNode`, search the left subtree
                currentNode = node.left
            } else {
                // `targt` is equal to `currentNode`
                // It's rank is the accumulated rank so far and the size of it's left tree
                return rankCount + (node.left?.size ?? 0)
            }
        }

        // `target` is not in the tree, but rankCount naturally holds the index of the lower-bound!
        return rankCount
    }
}


// MARK: - Tree/Search

fileprivate func treeSearch(from node: AVLNode?, for score: Double, and member: ByteBuffer) -> AVLNode?{
    var searchNode = node
    // Using a loop instead of recursion uses O(1) stack space
    while let current = searchNode {
        let r = current.compares(toScore: score, targetMember: member)

        if r < 0 { // node < target
            searchNode = current.right
        }else if r > 0 { // node > target
            searchNode = current.left
        }else{ // node == target
            return current
        }
    }

    return nil
}

// MARK: - Tree/Iterator

struct AVLTreeIterator: IteratorProtocol {
    // TODO: Support iterating in the reverse direction from the biggest to the smallest

    private var stack: [AVLNode] = []

    init(_ rootNode: AVLNode?, startingFrom target: (score: Double, member: ByteBuffer)? = nil){
        guard let target = target else {
            // No `target` specified, so we need to iterate from the smallest node
            // Build a stack from the `rootNode` to the smallest node
            var leftTarget: AVLNode? = rootNode
            while leftTarget != nil {
                self.stack.append(leftTarget!)
                leftTarget = leftTarget?.left
            }
            return
        }

        // Keep track of the relevant nodes from `rootNode` to the target node that meets `target`
        var searchNode: AVLNode? = rootNode
        while let current = searchNode {
            let cmp = current.compares(toScore: target.score, targetMember: target.member)
            if cmp < 0 { // `current` is less than `target`
                searchNode = current.right
            }else{
                // A candidate node that is >= target has been found.
                self.stack.append(current)
                // Continue searching as there could be an even smaller node than `current` that
                // is still >= `target`
                searchNode = current.left
            }
        }
    }

    mutating func next() -> AVLNode? {
        guard let nextElement = self.stack.popLast() else {
            return nil
        }

        if nextElement.right != nil {
            // Traverse the entire left-spine of `nextElement` and add them to the stack
            var nodeToAdd = nextElement.right
            while let futureElement = nodeToAdd {
                self.stack.append(futureElement)
                nodeToAdd = nodeToAdd?.left
            }
        }

        return nextElement
    }
}