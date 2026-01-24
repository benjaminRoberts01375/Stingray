//
//  RError.swift
//  Stingray
//
//  Created by Ben Roberts on 1/24/26.
//

import Foundation

protocol RError: LocalizedError {
    /// Next available error in the chain of errors.
    var next: (any Error)? { get }
    /// Description of this error.
    var errorDescription: String { get }
}

/// Extend RError to print recursive descriptions.
extension RError {
    /// Recursive description. Prints this error's description and all subsequent ones.
    /// - Returns: Formatted description.
    func rDescription() -> String {
        var parts: [String] = [errorDescription]
        var current = next
        
        while let err = current {
            if let rErr = err as? RError {
                parts.append(rErr.errorDescription)
                current = rErr.next
            } else if let localErr = err as? LocalizedError {
                parts.append(localErr.errorDescription ?? err.localizedDescription)
                break
            } else {
                parts.append(err.localizedDescription)
                break
            }
        }
        
        return parts.joined(separator: " -> ")
    }
}
