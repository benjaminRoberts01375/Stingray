//
//  IntExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 3/25/26.
//

import Foundation

/// Dedicated to formatting an int of bits per second to megabits per second
extension Int {
    /// Formats an int of bits per second to megabits per second
    /// - Parameter bits: Per second.
    /// - Returns: Formatted string.
    public static func formatMegabitsPerSec(_ bits: Int?) -> String {
        guard let bits = bits else { return "Maximum" }
        let mbps = Double(bits) / 1_000_000
        let formatted = mbps.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", mbps) : String(mbps)
        return "\(formatted) Mbps"
    }
}
