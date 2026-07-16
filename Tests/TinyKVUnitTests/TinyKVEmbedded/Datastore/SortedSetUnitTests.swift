import Testing
import NIOCore
@testable import TinyKVEmbedded

struct SortedSetUnitTests {
    let allocator = ByteBufferAllocator()

    @Test 
    func canInsertIntoSortedSet() {
        let specimen = self.createSpecimen()
        let expectedState = self.insertRandomItems(into: specimen)

        // Verify `expectedState` elements are present in the underlying tree and hashmap
        expectedState.forEach { (member: ByteBuffer, score: Double) in 
            #expect(specimen.tree.lookup(score: score, member: member) == true)
            #expect(specimen.hashmap.lookup(key: member) == score)
        }
    }

    @Test
    func canUpsertInSortedSet() {
        let specimen = self.createSpecimen()
        let member: ByteBuffer = buffer("C")
        let oldScore = 20.0
        let newScore: Double = 1000

        specimen.insert(member: buffer("A"), with: 10.0)
        specimen.insert(member: buffer("B"), with: -10.0)

        let insertResult1 = specimen.insert(member: member, with: oldScore)
        // Update the value for `C`
        let insertResult2 = specimen.insert(member: member, with: newScore)

        // Verify the upsert has occured
        #expect(insertResult1 == .added)
        #expect(insertResult2 == .updated)
        #expect(specimen.tree.lookup(score: oldScore, member: member) == false, "The AVLTree should no longer contain the old score")
        #expect(specimen.tree.lookup(score: newScore, member: member) == true, "The AVLTree should have the new score")
        #expect(specimen.hashmap.lookup(key: member) == newScore)
    }

    @Test
    func canDeleteFromSortedSet() {
        let specimen = self.createSpecimen()
        let expectedState = self.insertRandomItems(into: specimen, count: 15)

        expectedState.forEach({ (member, _) in 
            #expect(specimen.delete(member) == true, "Failed to delete \(String(buffer: member)) from sorted set")
        })

        // Verify `specimen` has been completely drained
        #expect(specimen.tree.rootNode == nil, "The tree should be completely dead")
        #expect(specimen.hashmap.newerHashTable.count == 0)
        #expect(specimen.hashmap.oldHashTable == nil)
    }

    func createSpecimen() -> SortedSet {
        return SortedSet()
    }

    func insertRandomItems(into sortedSet: SortedSet, count: Int = 10) -> [ByteBuffer : Double] {
        var expectedState: [ByteBuffer: Double] = [:]
        for _ in 0..<count {
            let randomScore = Double.random(in: -100...100)
            let randomString = randomAlphanumericString(length: Int(abs(randomScore)))
            expectedState[buffer(randomString)] = randomScore
        }

        expectedState.forEach { (member: ByteBuffer, score: Double) in 
            sortedSet.insert(member: member, with: score)
        }

        return expectedState
    }
}
