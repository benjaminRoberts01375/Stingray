//
//  SequenceExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 10/20/26.
//

import Foundation

extension Sequence {
    /// Creates an `AppendableIterator` with this sequence's elements.
    /// - Returns: An iterator that more elements can be appended to as it's consumed.
    public func makeAppendableIterator() -> AppendableIterator<Element> {
        return AppendableIterator(self)
    }
}
