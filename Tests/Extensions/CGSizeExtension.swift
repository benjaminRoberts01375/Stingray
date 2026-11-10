//
//  CGSizeExtension.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/9/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("CGSize divided by CGFloat")
struct CGSizeDivisionTests {
    /// Test dividing sizes by positive divisors
    /// - Parameters:
    ///   - size: Size to divide
    ///   - divisor: Positive divisor
    ///   - expected: Divided output
    @Test(arguments: [
        (CGSize(width: 10, height: 20), 1, CGSize(width: 10, height: 20)),
        (CGSize(width: 10, height: 20), 2, CGSize(width: 5, height: 10)),
        (CGSize(width: 1920, height: 1080), 4, CGSize(width: 480, height: 270)),
        (CGSize(width: 3, height: 5), 2, CGSize(width: 1.5, height: 2.5)),
        (CGSize(width: 10, height: 20), 0.5, CGSize(width: 20, height: 40)),
        (CGSize(width: 0, height: 0), 3, CGSize(width: 0, height: 0)),
    ] as [(CGSize, CGFloat, CGSize)])
    func dividesPositive(size: CGSize, divisor: CGFloat, expected: CGSize) {
        #expect(size / divisor == expected)
    }

    /// Test dividing sizes by negative divisors
    /// - Parameters:
    ///   - size: Size to divide
    ///   - divisor: Negative divisor
    ///   - expected: Divided output with flipped signs
    @Test(arguments: [
        (CGSize(width: 10, height: 20), -1, CGSize(width: -10, height: -20)),
        (CGSize(width: 10, height: 20), -2, CGSize(width: -5, height: -10)),
        (CGSize(width: -10, height: -20), -2, CGSize(width: 5, height: 10)),
        (CGSize(width: 10, height: -20), -0.5, CGSize(width: -20, height: 40)),
    ] as [(CGSize, CGFloat, CGSize)])
    func dividesNegative(size: CGSize, divisor: CGFloat, expected: CGSize) {
        #expect(size / divisor == expected)
    }

    /// Test dividing non-zero sizes by zero. Should result in signed infinity.
    /// - Parameters:
    ///   - size: Non-zero size to divide
    ///   - expected: Infinite output
    @Test(arguments: [
        (CGSize(width: 10, height: 20), CGSize(width: CGFloat.infinity, height: .infinity)),
        (CGSize(width: -10, height: -20), CGSize(width: -CGFloat.infinity, height: -.infinity)),
        (CGSize(width: 10, height: -20), CGSize(width: CGFloat.infinity, height: -.infinity)),
    ])
    func dividesByZero(size: CGSize, expected: CGSize) {
        #expect(size / 0 == expected)
    }

    /// Test dividing a zero size by zero. Should result in NaN.
    @Test
    func dividesZeroByZero() {
        let result = CGSize(width: 0, height: 0) / 0
        #expect(result.width.isNaN)
        #expect(result.height.isNaN)
    }
}
