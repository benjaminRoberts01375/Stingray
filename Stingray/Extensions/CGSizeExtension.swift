//
//  CGSizeExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 10/27/26.
//

import Foundation

/// Allow dividing a CGSize by some number
public extension CGSize {
    /// Allow dividing a CGSize by some number
    /// - Parameters:
    ///   - lhs: CGSize to divide
    ///   - rhs: Divisor
    /// - Returns: Divided CGSize
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
}
