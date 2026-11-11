//
//  TimeIntervalExtension.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/10/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("TimeInterval(ticks: Int)")
struct TimeIntervalInitTicksTests {
    /// Test converting positive Jellyfin ticks to seconds
    /// - Parameters:
    ///   - ticks: Postive ticks, where 1 tick = 1/10,000,000 second
    ///   - expected: Seconds
    @Test(arguments: [
        (Int(0), TimeInterval(0)),
        (1, 0.0000001),
        (5_000_000, 0.5),
        (10_000_000, 1.0),
        (15_000_000, 1.5),
        (600_000_000, 60.0),
        (36_000_000_000, 3600.0),
        (1_234_560_000_000, 123456.0),
    ])
    func positive(ticks: Int, expected: TimeInterval) {
        #expect(TimeInterval(ticks: ticks) == expected)
    }

    /// Test converting negative Jellyfin ticks to seconds
    /// - Parameters:
    ///   - ticks: Negative ticks, where 1 tick = 1/10,000,000 second
    ///   - expected: Negative seconds
    @Test(arguments: [
        (Int(-0), TimeInterval(0)),
        (-1, -0.0000001),
        (-5_000_000, -0.5),
        (-10_000_000, -1.0),
        (-15_000_000, -1.5),
        (-600_000_000, -60.0),
        (-36_000_000_000, -3600.0),
        (-1_234_560_000_000, -123456.0),
    ])
    func negative(ticks: Int, expected: TimeInterval) {
        #expect(TimeInterval(ticks: ticks) == expected)
    }
}

@Suite("TimeInterval.ticks")
struct TimeIntervalTicksTests {
    /// Test converting positive seconds to Jellyfin ticks
    /// - Parameters:
    ///   - seconds: Postive seconds
    ///   - expected: Ticks, where 1 tick = 1/10,000,000 second
    @Test(arguments: [
        (TimeInterval(0), Int(0)),
        (0.5, 5_000_000),
        (1.0, 10_000_000),
        (1.5, 15_000_000),
        (60.0, 600_000_000),
        (3600.0, 36_000_000_000),
        (123456.0, 1_234_560_000_000),
    ])
    func positive(seconds: TimeInterval, expected: Int) {
        #expect(seconds.ticks == expected)
    }

    /// Test converting negative seconds to Jellyfin ticks
    /// - Parameters:
    ///   - seconds: Negative seconds
    ///   - expected: Negative ticks, where 1 tick = 1/10,000,000 second
    @Test(arguments: [
        (TimeInterval(-0.0), Int(0)),
        (-0.5, -5_000_000),
        (-1.0, -10_000_000),
        (-1.5, -15_000_000),
        (-60.0, -600_000_000),
        (-3600.0, -36_000_000_000),
        (-123456.0, -1_234_560_000_000),
    ])
    func negative(seconds: TimeInterval, expected: Int) {
        #expect(seconds.ticks == expected)
    }

    /// Test that anything smaller than a tick is truncated toward zero rather than rounded
    /// - Parameters:
    ///   - seconds: Seconds with a sub-tick remainder
    ///   - expected: Truncated ticks
    @Test(arguments: [
        (TimeInterval(0.00000005), Int(0)),
        (0.00000009, 0),
        (1.99999999, 19_999_999),
        (-0.00000005, 0),
        (-0.00000009, 0),
        (-1.99999999, -19_999_999),
    ])
    func truncates(seconds: TimeInterval, expected: Int) {
        #expect(seconds.ticks == expected)
    }

    /// Test setting ticks replaces the existing value with the equivalent seconds
    /// - Parameters:
    ///   - ticks: Ticks to assign
    ///   - expected: Seconds after assignment
    @Test(arguments: [
        (Int(0), TimeInterval(0)),
        (5_000_000, 0.5),
        (25_000_000, 2.5),
        (36_000_000_000, 3600.0),
        (-20_000_000, -2.0),
        (-5_000_000, -0.5),
    ])
    func setter(ticks: Int, expected: TimeInterval) {
        var interval: TimeInterval = 99
        interval.ticks = ticks
        #expect(interval == expected)
    }
}
