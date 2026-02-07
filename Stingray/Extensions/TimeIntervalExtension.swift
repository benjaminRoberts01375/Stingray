//
//  TimeIntervalExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 1/29/26.
//

import Foundation

/// Extend the TimeInterval type to handle Jellyfin ticks
public extension TimeInterval {
    /// Create a TimeInterval from Jellyfin ticks
    /// - Parameter ticks: Number of ticks. 1 tick = 1/10,000,000 second.
    init(ticks: Int) { self = Double(ticks) / 10_000_000.0 }
    
    /// Value of a this `TimeInterval` in Jellyfin ticks
    var ticks: Int {
        get { Int(self * 10_000_000) }
        set { self = Double(newValue) / 10_000_000 }
    }
}
