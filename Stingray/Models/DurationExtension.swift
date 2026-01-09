//
//  DurationExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 11/20/25.
//

/// Extend the Duration type to have a rounded time option
extension Duration {
    /// Rounds a duration into a neatly formatted string.
    /// - Returns: A neatly formatted string.
    public func roundedTime() -> String {
        let totalSeconds = Int(self.components.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)\(hours != 1 ? " hours" : " hour") \(minutes)\(minutes != 1 ? " minutes" : " minute")"
        }
        return "\(minutes)\(minutes != 1 ? " minutes" : " minute")"
    }
}
