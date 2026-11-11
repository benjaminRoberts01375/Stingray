//
//  StingrayTVOSTests.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/9/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("String(duration: TimeInterval)")
struct StringTimeIntervalTests {
    /// Test conversion from duration to timecode with negative seconds
    /// - Parameters:
    ///   - seconds: Negative seconds to test
    ///   - expected: Negitive output
    @Test(arguments: [
        (-0.0, "0:00"),
        (-0.5, "0:00"),
        (-1.0, "-0:01"),
        (-1.1, "-0:01"),
        (-1.9, "-0:01"),
        (-25.0, "-0:25"),
        (-71.0, "-1:11"),
        (-610.0, "-10:10"),
        (-3934.0, "-1:05:34"),
        (-100005.0, "-27:46:45"),
        (-1000007.0, "-277:46:47"),
        ])
    func formatsNegative(seconds: TimeInterval, expected: String) {
        #expect(String(duration: seconds) == expected)
    }

    /// Test conversion from duration to timecode with positive seconds
    /// - Parameters:
    ///   - seconds: Postive seconds to test
    ///   - expected: Postive output
    @Test(arguments: [
        (0.0, "0:00"),
        (0.5, "0:00"),
        (1.0, "0:01"),
        (1.1, "0:01"),
        (1.9, "0:01"),
        (25.0, "0:25"),
        (71.0, "1:11"),
        (610.0, "10:10"),
        (3934.0, "1:05:34"),
        (100005.0, "27:46:45"),
        (1000007.0, "277:46:47"),
    ])
    func formatsPositive(seconds: TimeInterval, expected: String) {
        #expect(String(duration: seconds) == expected)
    }
    
    /// Test against typically out-of-bounds inputs like infinity. Should result in "0:00".
    /// - Parameter seconds: Strange seconds to test
    @Test(arguments: [ Foundation.TimeInterval.nan, .infinity, -.infinity, ])
    func formatsTimecode(seconds: TimeInterval) {
        #expect(String(duration: seconds) == "0:00")
    }
}

@Suite("String(duration: Duration)")
struct StringDurationTests {
    /// Test formatting negative durations
    /// - Parameters:
    ///   - duration: Negative duration to test
    ///   - expected: Negative output
    @Test(arguments: [
        (Duration.milliseconds(-500), "0 minutes"),
        (.seconds(-59), "0 minutes"),
        (.seconds(-60), "-1 minute"),
        (.seconds(-61), "-1 minute"),
        (.seconds(-120), "-2 minutes"),
        (.seconds(-3599), "-59 minutes"),
        (.seconds(-3600), "-1 hour 0 minutes"),
        (.seconds(-3660), "-1 hour 1 minute"),
        (.seconds(-3720), "-1 hour 2 minutes"),
        (.seconds(-7260), "-2 hours 1 minute"),
        (.seconds(-90000), "-25 hours 0 minutes"),
    ])
    func formatsNegative(duration: Duration, expected: String) {
        #expect(String(duration: duration) == expected)
    }

    /// Test formatting durations under an hour
    /// - Parameters:
    ///   - duration: Duration under an hour to test
    ///   - expected: Minutes-only output
    @Test(arguments: [
        (Duration.zero, "0 minutes"),
        (.seconds(59), "0 minutes"),
        (.seconds(60), "1 minute"),
        (.seconds(61), "1 minute"),
        (.seconds(119), "1 minute"),
        (.seconds(120), "2 minutes"),
        (.seconds(1500), "25 minutes"),
        (.seconds(3599), "59 minutes"),
    ])
    func formatsMinutes(duration: Duration, expected: String) {
        #expect(String(duration: duration) == expected)
    }

    /// Test formatting durations of an hour or more
    /// - Parameters:
    ///   - duration: Duration of at least an hour to test
    ///   - expected: Hours and minutes output
    @Test(arguments: [
        (Duration.seconds(3600), "1 hour 0 minutes"),
        (.seconds(3660), "1 hour 1 minute"),
        (.seconds(3720), "1 hour 2 minutes"),
        (.seconds(7200), "2 hours 0 minutes"),
        (.seconds(7260), "2 hours 1 minute"),
        (.seconds(9000), "2 hours 30 minutes"),
        (.seconds(90000), "25 hours 0 minutes"),
    ])
    func formatsHours(duration: Duration, expected: String) {
        #expect(String(duration: duration) == expected)
    }

    /// Test that sub-minute remainders are truncated rather than rounded
    /// - Parameters:
    ///   - duration: Duration with a sub-minute remainder
    ///   - expected: Truncated output
    @Test(arguments: [
        (Duration.milliseconds(500), "0 minutes"),
        (.milliseconds(59_999), "0 minutes"),
        (.milliseconds(60_001), "1 minute"),
        (.seconds(3659), "1 hour 0 minutes"),
        (.milliseconds(3_719_999), "1 hour 1 minute"),
    ])
    func truncatesSeconds(duration: Duration, expected: String) {
        #expect(String(duration: duration) == expected)
    }
}
