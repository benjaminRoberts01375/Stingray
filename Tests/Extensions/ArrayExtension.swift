//
//  ArrayExtension.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/9/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("Array.chunked(into:)")
struct ArrayChunkedTests {
    /// Test chunking arrays whose length is evenly divisible by the chunk size
    /// - Parameters:
    ///   - array: Array to chunk
    ///   - size: Max length of each chunk
    ///   - expected: Chunked output
    @Test(arguments: [
        ([1, 2], 1, [[1], [2]]),
        ([1, 2, 3, 4], 2, [[1, 2], [3, 4]]),
        ([1, 2, 3, 4, 5, 6], 3, [[1, 2, 3], [4, 5, 6]]),
        ([1, 2, 3, 4, 5, 6], 6, [[1, 2, 3, 4, 5, 6]]),
    ] as [([Int], Int, [[Int]])])
    func chunksEvenly(array: [Int], size: Int, expected: [[Int]]) {
        #expect(array.chunked(into: size) == expected)
    }

    /// Test chunking arrays that leave a shorter final chunk
    /// - Parameters:
    ///   - array: Array to chunk
    ///   - size: Max length of each chunk
    ///   - expected: Chunked output with a trailing remainder
    @Test(arguments: [
        ([1, 2, 3], 2, [[1, 2], [3]]),
        ([1, 2, 3, 4, 5], 2, [[1, 2], [3, 4], [5]]),
        ([1, 2, 3, 4, 5, 6, 7], 3, [[1, 2, 3], [4, 5, 6], [7]]),
        ([1, 2, 3, 4, 5], 4, [[1, 2, 3, 4], [5]]),
    ] as [([Int], Int, [[Int]])])
    func chunksWithRemainder(array: [Int], size: Int, expected: [[Int]]) {
        #expect(array.chunked(into: size) == expected)
    }

    /// Test chunk sizes larger than the array. Should result in a single chunk containing the whole array.
    /// - Parameter size: Chunk size larger than the array
    @Test(arguments: [4, 5, 100, Int.max])
    func chunksOversized(size: Int) {
        #expect([1, 2, 3].chunked(into: size) == [[1, 2, 3]])
    }

    /// Test chunking an empty array. Should result in no chunks.
    /// - Parameter size: Chunk size to test
    @Test(arguments: [1, 2, 100])
    func chunksEmpty(size: Int) {
        #expect([Int]().chunked(into: size).isEmpty)
    }

    /// Test negative chunk sizes. Should result in no chunks.
    /// - Parameter size: Negative chunk size to test
    @Test(arguments: [-1, -2, -100, Int.min])
    func chunksNegative(size: Int) {
        #expect([1, 2, 3].chunked(into: size).isEmpty)
    }
}
