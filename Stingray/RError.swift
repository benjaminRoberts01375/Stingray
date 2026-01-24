//
//  RError.swift
//  Stingray
//
//  Created by Ben Roberts on 1/24/26.
//

import Foundation

public protocol RError: LocalizedError {
    /// Next available error in the chain of errors.
    var next: (any RError)? { get }
    /// Description of this error.
    var errorDescription: String { get }
}

/// Extend RError to print recursive descriptions.
extension RError {
    /// Recursive description. Prints this error's description and all subsequent ones.
    /// - Returns: Formatted description.
    public func rDescription() -> String {
        var parts: [String] = [errorDescription]
        var current = next
        
        while let err = current {
            parts.append(err.errorDescription)
            current = err.next
        }
        
        return parts.joined(separator: " -> ")
    }
}
