//
//  LoggerModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/11/26.
//

import OSLog

/// A nice wrapper around the `Logger` type.
final class Log {
    /// Shared instance of the `Log` singleton.
    private static let shared = Log()
    
    /// Hook into system logging
    private let logger: Logger
    
    /// Private due to singleton.
    private init() {
        self.logger = Logger(subsystem: "com.benlab.Stingray", category: "StingrayLogging")
        self.logger.debug("Setting up logging...") // Direct call, no singleton access
    }
    
    /// Verbose dev-only info - not stored.
    /// - Parameter message: Message to log.
    /// - Note: Meant for variable values, flow tracing, and other debugging.
    /// - Important: Logs are set to public, so show no secrets.
    static func debug(_ message: String) {
        Log.shared.logger.debug("\(message, privacy: .public)")
    }
    
    /// Useful runtime info and app flow - stored briefly.
    /// - Parameter message: Message to log.
    /// - Note: Data only slightly more important than debug info, like a profile loading, or an API completed setup,
    /// - Important: Logs are set to public, so show no secrets.
    static func info(_ message: String) {
        Log.shared.logger.info("\(message, privacy: .public)")
    }
    
    /// Unexpected but recoverable issue cropped up.
    /// - Parameter message: Message to log.
    /// - Note: Meant to display a recoverable issue, and perhaps a retry was attempted, like a missing key in JSON.
    /// - Important: Logs are set to public, so show no secrets.
    static func warning(_ message: String) {
        Log.shared.logger.warning("\(message, privacy: .public)")
    }
    
    /// Something failed, but the lights are still on.
    /// - Parameter message: Message to log
    /// - Note: Something is unrecoverable, like a library failed to load.
    /// - Important: Logs are set to public, so show no secrets.
    static func error(_ message: String) {
        Log.shared.logger.error("\(message, privacy: .public)")
    }
    
    /// The app can no longer function. Use sparingly.
    /// - Parameter message: Message to save.
    /// - Note: Completely unrecoverable, the user is either stuck or the app is about to crash.
    /// - Important: Logs are set to public, so show no secrets.
    static func critical(_ message: String) {
        Log.shared.logger.critical("\(message, privacy: .public)")
    }
}
