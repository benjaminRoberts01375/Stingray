//
//  StringExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 12/3/25.
//

import Foundation

extension String {
    init(ticks: Int) {
        let seconds = Int(Double(ticks) / 10_000_000)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = (seconds % 3600) % 60
        self = String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
}
