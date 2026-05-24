//
//  ArrayExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 5/9/26.
//

import Foundation

/// Extend the Array functionality with chunked arrays
public extension Array {
    /// Break an array up into a series of subarrays
    /// - Parameter size: Max length of a subarray
    /// - Returns: Array of subarray
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
