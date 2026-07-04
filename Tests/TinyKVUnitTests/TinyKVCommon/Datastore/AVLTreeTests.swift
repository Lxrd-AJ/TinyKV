import Testing
import NIOCore
@testable import TinyKVCommon

struct AVLTreeUnitTests {
    let allocator = ByteBufferAllocator()

    @Test func canUpdateNodes() throws {
        // Create some nodes
        let A = AVLNode(score: 10, member: self.stringBuffer("A"))
        let B = AVLNode(score: 12, member: self.stringBuffer("B"))
        let C = AVLNode(score: 30, member: self.stringBuffer("C"))
        let T = AVLNode(score: 15, member: self.stringBuffer("T"))
        let Q = AVLNode(score: 35, member: self.stringBuffer("Q"))

        // Build a structure
        B.left = A
        B.right = C
        C.left = T
        C.right = Q

        // Do a manual bottoms up update
        Q.update(); T.update(); C.update(); A.update(); B.update();

        // Verify the balance factors and heights
        #expect(Q.balanceFactor() == 0 && Q.height == 1)
        #expect(T.height == 1 && T.balanceFactor() == 0)
        #expect(A.height == 1 && A.balanceFactor() == 0)
        #expect(C.height == 2 && C.balanceFactor() == 0)
        #expect(B.height == 3 && B.balanceFactor() == -1)
    }

    @Test func testRotateLeft() throws {
        let tree = AVLTree()
        let A = AVLNode(score: 10, member: self.stringBuffer("A"))
        let B = AVLNode(score: 20, member: self.stringBuffer("B"))
        let innerNode = AVLNode(score: 15, member: self.stringBuffer("inner"))

        A.right = B
        B.left = innerNode
        
        innerNode.update()
        B.update()
        A.update()

        let newRoot = try tree.rotateLeft(A)

        #expect(newRoot === B)
        #expect(B.left === A)
        #expect(A.right === innerNode)
        
        #expect(A.height == 2)
        #expect(B.height == 3)
    }

    @Test func testRotateRight() throws {
        let tree = AVLTree()
        let A = AVLNode(score: 20, member: self.stringBuffer("A"))
        let B = AVLNode(score: 10, member: self.stringBuffer("B"))
        let innerNode = AVLNode(score: 15, member: self.stringBuffer("inner"))

        A.left = B
        B.right = innerNode
        
        innerNode.update()
        B.update()
        A.update()

        let newRoot = try tree.rotateRight(A)

        #expect(newRoot === B)
        #expect(B.right === A)
        #expect(A.left === innerNode)
        
        #expect(A.height == 2)
        #expect(B.height == 3)
    }

    @Test func testBalanceLeftHeavyStraightLine() throws {
        let tree = AVLTree()
        let A = AVLNode(score: 30, member: self.stringBuffer("A"))
        let B = AVLNode(score: 20, member: self.stringBuffer("B"))
        let C = AVLNode(score: 10, member: self.stringBuffer("C"))

        A.left = B
        B.left = C
        
        C.update()
        B.update()
        A.update()

        let newRoot = try tree.balance(A)

        #expect(newRoot === B)
        #expect(B.right === A)
        #expect(B.left === C)
    }

    @Test func testBalanceLeftHeavyZigzag() throws {
        let tree = AVLTree()
        let A = AVLNode(score: 30, member: self.stringBuffer("A"))
        let B = AVLNode(score: 10, member: self.stringBuffer("B"))
        let C = AVLNode(score: 20, member: self.stringBuffer("C"))

        A.left = B
        B.right = C
        
        C.update()
        B.update()
        A.update()

        let newRoot = try tree.balance(A)

        #expect(newRoot === C)
        #expect(C.left === B)
        #expect(C.right === A)
    }
}

extension AVLTreeUnitTests{
    func stringBuffer(_ contents: String) -> ByteBuffer {
        return self.allocator.buffer(string: contents)
    }
}
