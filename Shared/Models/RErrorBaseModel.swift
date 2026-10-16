//
//  RErrorBaseModel.swift
//  Stingray
//
//  Created by Ben Roberts on 10/16/26.
//

import Foundation

// The Foundation-only core of Stingray's errors: the `RError` protocol and the errors thrown by the shared network transport.
// Kept apart from RErrorModel.swift, which imports StoreKit, so the Top Shelf extension can share this file without the rest.

/// A "Recursive Error", allows for creating a linked list of errors to create a stack trace.
public protocol RError: LocalizedError {
    /// Next available error in the chain of errors.
    var next: (any RError)? { get }
    /// Description of this error.
    var errorDescription: String { get }
}

/// Extend RError to log recursive descriptions.
extension RError {
    /// Recursive description. Logs this error's description and all subsequent ones.
    /// - Returns: Formatted description.
    public func rDescription() -> String {
        var parts: [String] = [errorDescription]
        var current = next

        while let err = current {
            parts.append(err.errorDescription)
            current = err.next
        }

        let total = "\n\t→ \(parts.joined(separator: "\n\t→ "))"
        return total
    }

    /// Gets the last error in the chain of errors. Useful for writing summary error messages
    /// - Returns: The last error in the chain
    public func last() -> (any RError) {
        var current: RError = self
        while let next = current.next {
            current = next
        }
        return current
    }
}

/// Extend arrays of `RError` to provide recursive descriptions formatted in a reasonable manner.
extension [RError] {
    /// Recursive description. Logs this error's description and all subsequent ones.
    /// - Returns: Formatted description.
    public func rDescription() -> String {
        let total = self.reduce("") { (result, error) -> String in
            return result + "\n\t→ \(error.errorDescription)"
        }
        return total
    }
}

// MARK: Error Implementations
/// Different ways a network can have an error.
public enum NetworkError: RError {
    /// The request URL was invalid.
    case invalidURL(String)
    /// Could not encode JSON.
    case encodeJSONFailed(Error)
    /// Could not send the payload
    case requestFailedToSend(Error)
    /// Response was bad in some way
    case badResponse(responseCode: Int, response: String?)
    /// Could not decode the returned JSON
    case decodeJSONFailed((any Error)?, url: URL?)
    /// An access token is needed
    case missingAccessToken

    public var next: (any RError)? {
        switch self {
        case .decodeJSONFailed(let error, _):
            if let rErr = error as? RError { return rErr }
            return nil
        default: return nil
        }
    }

    public var errorDescription: String {
        switch self {
        case .invalidURL(let description):
            return "The requested URL was invalid: \(description)"
        case .encodeJSONFailed(let err):
            return "Unable to encode JSON: \(err.localizedDescription)"
        case .requestFailedToSend(let err):
            return "Request failed to send: \(err.localizedDescription)"
        case .badResponse(let code, let text):
            return "Received a bad response from the server - \(code) \(text ?? "")"
        case .decodeJSONFailed(let error, let url):
            if error as? RError == nil {
                return "Failed to decode JSON from \(url?.absoluteString ?? "an unknown URL")"
            }
            return "Failed to decode JSON from \(url?.absoluteString ?? "an unknown URL"). \(error?.localizedDescription ?? "")"
        case .missingAccessToken:
            return "An access token is needed"
        }
    }

    /// A function to override `NetworkError` messages with a more human readable option
    /// - Parameters:
    ///   - netErr: NetworkError that was thrown
    ///   - httpProtocol: HTTP protocol used
    /// - Returns: Formatted error
    public static func overrideNetErrorMessage(netErr: NetworkError, httpProtocol: HttpProtocol) -> String {
        switch netErr {
        case .invalidURL:
            switch httpProtocol {
            case .http: return "Invalid HTTP URL. Check your hostname and port."
            case .https: return "Invalid HTTPS URL. Check your URL."
            }
        case .encodeJSONFailed: return "Failed to send request to server. " +
            "This may be because of some tricky characters in your username and password."
        case .decodeJSONFailed, .missingAccessToken, .requestFailedToSend:
            switch httpProtocol {
            case .http: return "Could not find your Jellyfin server. Please check your hostname and port."
            case .https: return "Could not find your Jellyfin server. Please check your URL."
            }
        case .badResponse(let responseCode, _):
            switch responseCode {
            case 401: return "Invalid username or password."
            case 404:
                switch httpProtocol {
                case .http: return "Could not find your Jellyfin server. Please check your hostname and port."
                case .https: return "Could not find your Jellyfin server. Please check your URL."
                }
            default: return "An unexpected error occurred. Please make sure your login details are correct."
            }
        }
    }
}

/// HTTP protocol types
public enum HttpProtocol: String, CaseIterable {
    /// Plain insecure HTTP >:(
    case http = "http"
    /// HTTPS. The good stuff
    case https = "https"
}
