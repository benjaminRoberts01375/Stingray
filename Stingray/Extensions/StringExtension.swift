//
//  StringExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 12/3/25.
//

import Foundation

/// Extend the String type to create a neatly formatted string from Ticks
extension String {
     /// Creates a neatly formatted timecode from a time interval.
     /// The most significant component is never zero-padded, and the hours component is omitted entirely for durations under an hour. Any
     /// fractional seconds are truncated
     /// ```swift
     /// String(duration: 10)   // "0:10"  (10 seconds)
     /// String(duration: 70)   // "1:10"  (1 minute, 10 seconds)
     /// String(duration: 600)  // "10:00" (10 minutes)
     /// String(duration: 3900) // "1:05:00" (1 hour, 5 minutes)
     /// ```
     /// - Parameter duration: The length of time to format, in seconds. Negative values are not supported and produce a malformed timecode
    public init(duration: TimeInterval) {
        let seconds = Int(duration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = (seconds % 3600) % 60
        // Hours present: show every component, padding minutes and seconds to two digits
        if hours != .zero {
            self = String(format: "%d:%02d:%02d", hours, minutes, secs)
            return
        }
        // Under ten minutes: leave the minutes component unpadded (0:10 rather than 00:10)
        if minutes < 10 {
            self = String(format: "%d:%02d", minutes, secs)
            return
        }
        self = String(format: "%02d:%02d", minutes, secs)
    }
}

/// Extend the `String` type to convert PascalCase to words separated by spaces. Ex. "MyName" -> "My Name"
/// Made by an LLM - modified by a person
extension String {
    /// Inserts a space before every capital letter, splitting PascalCase into separate words.
    /// Existing capitalization is preserved, so the first character is left exactly as it was found.
    /// ```swift
    /// "MyCoolMovieTitle".pascalCaseToSpaces() // "My Cool Movie Title"
    /// "myCoolMovieTitle".pascalCaseToSpaces() // "my Cool Movie Title"
    /// ```
    /// - Returns: The spaced-out string
    public func pascalCaseToSpaces() -> String {
        // Handle empty strings
        if self.isEmpty { return self }
        
        var result = ""
        for (index, character) in self.enumerated() {
            // Make sure we don't add a random space at the start of the string
            let isFirst = index == 0
            let isUppercase = character.isUppercase
            if isUppercase && !isFirst { result.append(" ") }
            
            // Add to string. Shouldn't be *too* bad since arrays grow by doubling the capacity
            result.append(character)
        }
        
        return result
    }
}
