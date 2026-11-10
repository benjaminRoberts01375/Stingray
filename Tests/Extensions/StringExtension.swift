//
//  StingrayTVOSTests.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/9/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("String(duration:)")
struct StringDurationTests {
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
