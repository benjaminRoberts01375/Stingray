//
//  ISO8601DateFormatterExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 10/14/26.
//

import Foundation

/// Shared date formatter for Jellyfin's ISO-8601 timestamps.
public extension ISO8601DateFormatter {
    /// Reused across decodes; allocating an `ISO8601DateFormatter` is expensive and `date(from:)` is
    /// thread-safe once the format options are configured.
    static let jellyfin: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
