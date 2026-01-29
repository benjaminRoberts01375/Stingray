//
//  StringExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 12/3/25.
//

import Foundation

/// Extend the String type to create a neatly formatted string from Ticks
extension String {
    /// Create a neatly formatted string based off the number of ticks a stream may have.
    /// 10,000,000 ticks = 1 second.
    /// - Parameter ticks: Stream ticks
    init(ticks: Int) {
        let seconds = Int(Double(ticks) / 10_000_000)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = (seconds % 3600) % 60
        self = String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
}

/// Extend the `String` type to convert PascalCase to word with spaces. Ex. "MyName" ->
/// Example: "MyName" -> "My Name"
/// Made by an LLM - modified by a human
extension String {
    /// Converts a PascalCase string to a space-separated string
    /// Example: "MyName" -> "My Name"
    func pascalCaseToSpaces() -> String {
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
