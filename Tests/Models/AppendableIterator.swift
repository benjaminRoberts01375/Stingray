//
//  AppendableIterator.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/10/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("AppendableIterator")
struct AppendableIteratorTests {
    /// Test that an iterator created from a sequence yields its elements in order, then `nil`
    /// - Parameter initial: Initial elements
    @Test(arguments: [
        [Int](),
        [1],
        [1, 2, 3],
        [3, 1, 2, 1, 3],
    ])
    func iteratesInitialElements(initial: [Int]) {
        let iterator = AppendableIterator(initial)
        for element in initial {
            #expect(iterator.next() == element)
        }
        #expect(iterator.next() == nil)
        #expect(iterator.next() == nil) // Stays nil
    }

    /// Test that the empty initializer starts empty
    @Test
    func emptyInit() {
        let iterator = AppendableIterator<Int>()
        #expect(iterator.isEmpty)
        #expect(iterator.current == nil)
        #expect(iterator.storage.isEmpty)
        #expect(iterator.next() == nil)
    }

    /// Test that `current` peeks without advancing
    @Test
    func currentDoesNotAdvance() {
        let iterator = AppendableIterator([1, 2])
        #expect(iterator.current == 1)
        #expect(iterator.current == 1)
        #expect(iterator.next() == 1)
        #expect(iterator.current == 2)
        #expect(iterator.next() == 2)
        #expect(iterator.current == nil)
    }

    /// Test that `isEmpty` does eventually become true
    @Test
    func isEmptyTracksConsumption() {
        let iterator = AppendableIterator([1, 2])
        #expect(!iterator.isEmpty)
        _ = iterator.next()
        #expect(!iterator.isEmpty)
        _ = iterator.next()
        #expect(iterator.isEmpty)
    }

    /// Test that appended elements are returned after the initial ones
    @Test
    func appendSingle() {
        let iterator = AppendableIterator([1])
        iterator.append(2)
        iterator.append(3)
        #expect(iterator.next() == 1)
        #expect(iterator.next() == 2)
        #expect(iterator.next() == 3)
        #expect(iterator.next() == nil)
    }

    /// Test that appending a sequence preserves order
    @Test
    func appendContentsOf() {
        let iterator = AppendableIterator([1])
        iterator.append(contentsOf: [2, 3])
        iterator.append(contentsOf: [Int]())
        iterator.append(contentsOf: 4...5)
        #expect(Array(iterator) == [1, 2, 3, 4, 5])
    }

    /// Test that elements appended after the iterator was exhausted are still returned
    @Test
    func appendAfterExhaustion() {
        let iterator = AppendableIterator([1])
        #expect(iterator.next() == 1)
        #expect(iterator.next() == nil)
        #expect(iterator.isEmpty)

        iterator.append(2)
        #expect(!iterator.isEmpty)
        #expect(iterator.current == 2)
        #expect(iterator.next() == 2)
        #expect(iterator.next() == nil)
    }

    /// Test that appending mid-iteration continues from the current position
    @Test
    func appendMidIteration() {
        let iterator = AppendableIterator([1, 2])
        #expect(iterator.next() == 1)
        iterator.append(3)
        #expect(iterator.next() == 2)
        #expect(iterator.next() == 3)
        #expect(iterator.next() == nil)
    }

    /// Test that consumed elements are retained in `storage`
    @Test
    func storageKeepsConsumed() {
        let iterator = AppendableIterator([1, 2])
        _ = iterator.next()
        iterator.append(3)
        #expect(iterator.storage == [1, 2, 3])
    }
}
