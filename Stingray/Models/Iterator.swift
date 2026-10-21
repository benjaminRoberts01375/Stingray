//
//  Iterator.swift
//  Stingray
//
//  Created by Ben Roberts on 10/20/26.
//

import Foundation

/// An iterator over a growable buffer. Elements can be appended at any time, including mid-iteration. `next()` returns `nil` only once
/// everything appended so far is consumed. AI generated - hand altered
public final class AppendableIterator<Element>: IteratorProtocol, Sequence {
    /// Current data in the iterator
    public private(set) var storage: [Element]
    /// Index of the iterator
    private var head: Int = 0
    /// Gets the current element
    /// - Returns: Get the current element
    public var current: Element? {
        if self.storage.isEmpty { return nil }
        else if self.head >= self.storage.count { return nil }
        return self.storage[self.head]
    }

    public init<S: Sequence>(_ initial: S) where S.Element == Element {
        self.storage = Array(initial)
    }

    public convenience init() { self.init([]) }

    /// `true` when there's nothing left to return right now
    public var isEmpty: Bool { self.storage.count == self.head }

    /// Adds a single element to the end of the queue.
    public func append(_ element: Element) { self.storage.append(element) }

    /// Adds a sequence of elements to the end of the queue
    public func append<S: Sequence>(contentsOf elements: S) where S.Element == Element {
        self.storage.append(contentsOf: elements)
    }

    /// Returns the next new value, or `nil` if the buffer is empty
    public func next() -> Element? {
        if self.head >= self.storage.count { return nil }
        let element = self.storage[self.head]
        self.head += 1
        return element
    }
}
