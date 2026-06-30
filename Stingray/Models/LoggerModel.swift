//
//  LoggerModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/11/26.
//

import Foundation
import OSLog

/// A nice wrapper around the `Logger` type.
public final class Log {
    /// Shared instance of the `Log` singleton.
    private static let shared = Log()
    
    /// Hook into system logging
    private let logger: Logger
    
    /// The most recent log entry
    public private(set) static var lastLogEntry: LogEntry?

    /// Private due to singleton.
    private init() {
        self.logger = Logger(subsystem: "com.benlab.Stingray", category: "StingrayLogging")
        self.logger.debug("Setting up logging...") // Direct call, no singleton access
    }
    
    /// Verbose dev-only info - not stored.
    /// - Parameter message: Message to log.
    /// - Note: Meant for variable values, flow tracing, and other debugging.
    /// - Important: Logs are set to public, so show no secrets.
    public static func debug(_ message: String) {
        Log.shared.logger.debug("\(message, privacy: .public)")
        Log.lastLogEntry = LogEntry(message: message, level: .debug, next: Log.lastLogEntry)
    }
    
    /// Useful runtime info and app flow - stored briefly.
    /// - Parameter message: Message to log.
    /// - Note: Data only slightly more important than debug info, like a profile loading, or an API completed setup,
    /// - Important: Logs are set to public, so show no secrets.
    public static func info(_ message: String) {
        Log.shared.logger.info("\(message, privacy: .public)")
        Log.lastLogEntry = LogEntry(message: message, level: .info, next: Log.lastLogEntry)
    }
    
    /// Unexpected but recoverable issue cropped up.
    /// - Parameter message: Message to log.
    /// - Note: Meant to display a recoverable issue, and perhaps a retry was attempted, like a missing key in JSON.
    /// - Important: Logs are set to public, so show no secrets.
    public static func warning(_ message: String) {
        Log.shared.logger.warning("\(message, privacy: .public)")
        Log.lastLogEntry = LogEntry(message: message, level: .warning, next: Log.lastLogEntry)
    }
    
    /// Something failed, but the lights are still on.
    /// - Parameter message: Message to log
    /// - Note: Something is unrecoverable, like a library failed to load.
    /// - Important: Logs are set to public, so show no secrets.
    public static func error(_ message: String) {
        Log.shared.logger.error("\(message, privacy: .public)")
        Log.lastLogEntry = LogEntry(message: message, level: .error, next: Log.lastLogEntry)
    }
    
    /// The app can no longer function. Use sparingly.
    /// - Parameter message: Message to save.
    /// - Note: Completely unrecoverable, the user is either stuck or the app is about to crash.
    /// - Important: Logs are set to public, so show no secrets.
    public static func critical(_ message: String) {
        Log.shared.logger.critical("\(message, privacy: .public)")
        Log.lastLogEntry = LogEntry(message: message, level: .critical, next: Log.lastLogEntry)
    }
}

/// A single logged value
public final class LogEntry: Encodable, Identifiable {
    /// Stable identity for use in SwiftUI lists.
    public let id = UUID()
    /// What the log actually says
    public let message: String
    /// The importance of the log
    public let level: LogLevel
    /// The next log message
    public fileprivate(set) var next: LogEntry?

    /// Creates a single log entry
    /// - Parameters:
    ///   - message: Message to display
    ///   - level: Importance of the log
    ///   - next: Next log in the list
    public init(message: String, level: LogLevel, next: LogEntry?) {
        self.message = message
        self.level = level
        self.next = next
    }
}

/// Denotes how important a log is
public enum LogLevel: String, Encodable, CaseIterable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"

    /// A localized, user-facing name for the log level.
    public var localized: String {
        switch self {
        case .debug: return String(localized: "Debug")
        case .info: return String(localized: "Info")
        case .warning: return String(localized: "Warning")
        case .error: return String(localized: "Error")
        case .critical: return String(localized: "Critical")
        }
    }

    /// Importance of the log relative to each other
    public var severity: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}
