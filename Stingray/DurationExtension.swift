//
//  DurationExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 11/20/25.
//

extension Duration {
    public func roundedTime() -> String {
        let totalSeconds = Int(self.components.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)hr \(minutes)mins"
        }
        return "\(minutes)mins"
    }
}
