//
//  RError.swift
//  Stingray
//
//  Created by Ben Roberts on 1/24/26.
//

import Foundation

public protocol RError: LocalizedError {
    /// Next available error in the chain of errors.
    var next: (any RError)? { get }
    /// Description of this error.
    var errorDescription: String { get }
}

/// Extend RError to print recursive descriptions.
extension RError {
    /// Recursive description. Prints this error's description and all subsequent ones.
    /// - Returns: Formatted description.
    public func rDescription() -> String {
        var parts: [String] = [errorDescription]
        var current = next
        
        while let err = current {
            parts.append(err.errorDescription)
            current = err.next
        }
        
        return "\n\t→ \(parts.joined(separator: "\n\t→ "))"
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

// MARK: Error Implementations

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
    case decodeJSONFailed((any RError)?, url: URL?)
    /// An access token is needed
    case missingAccessToken
    
    public var next: (any RError)? {
        switch self {
        case .decodeJSONFailed(let error, _): return error
        default: return nil
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .invalidURL(let description):
            return "The requested URL was invalid: \(description)"
        case .encodeJSONFailed:
            return "Unable to encode JSON"
        case .requestFailedToSend:
            return "Request failed to send"
        case .badResponse(let code, let text):
            return "Received a bad response from the server - \(code) \(text ?? "")"
        case .decodeJSONFailed(_, let url):
            return "Failed to decode JSON from \(url?.absoluteString ?? "an unknown URL")"
        case .missingAccessToken:
            return "An access token is needed"
        }
    }
}

public enum JSONError: RError {
    /// Denotes a missing entry in a given JSON object. First `String` denotes the key, and the second `String` denotes the object's name
    case missingKey(String, String)
    /// Denotes a missing JSON object within another JSON object. First `String` denotes the key,
    /// and the second `String` denotes the object's name
    case missingContainer(String, String)
    /// Failed to decode JSON at all. The `String` denotes the object's name, `Error` is the thrown JSON error
    case failedJSONDecode(String, Error)
    /// Failed to encode JSON at all. The `String` denotes the object's name
    case failedJSONEncode(String)
    /// The unwrapped key is an unexpected value.
    case unexpectedKey(RError)
    
    public var next: (any RError)? {
        switch self {
        case .unexpectedKey(let err): return err
        default: return nil
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .missingKey(let key, let objectName):
            return "The key \(key) was missing from the JSON object \(objectName)"
        case .missingContainer(let containerName, let parentObjectName):
            return "The JSON object \(containerName) was missing from the JSON object \(parentObjectName)"
        case .failedJSONDecode(let objectName, let error):
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON for \(objectName): Missing key '\(key.stringValue)' at \(path)"
                case .valueNotFound(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON for \(objectName): Missing value of type '\(type)' at \(path)"
                case .typeMismatch(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON for \(objectName): Type mismatch for '\(type)' at \(path). \
                        \(context.debugDescription)
                        """
                case .dataCorrupted(let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON for \(objectName): Data corrupted at \(path). \
                        \(context.debugDescription)
                        """
                @unknown default:
                    return "Unable to decode JSON  \(objectName): \(error.localizedDescription)"
                }
            }
            return "JSON failed to decode for \(objectName)"
        case .failedJSONEncode(let objectName):
            return "Failed to encode JSON for \(objectName)"
        case .unexpectedKey:
            return "The unwraped JSON value was unexpected"
        }
    }
}

public enum MediaError: RError {
    /// The media is an unknown type. The `String` value is the type attempted to be made
    case unknownMediaType(String)
    
    public var errorDescription: String {
        switch self {
        case .unknownMediaType:
            return "Unknown media type"
        }
    }
    
    public var next: (any RError)? { nil }
}

enum StreamingServiceErrors: RError {
    case LibrarySetupFailed(RError?)
    
    var errorDescription: String {
        switch self {
        case .LibrarySetupFailed:
            "Failed to create library"
        }
    }
    
    var next: (any RError)? {
        switch self {
        case .LibrarySetupFailed(let err):
            return err
        }
    }
}

public enum AdvancedNetworkErrors: RError {
    case failedRecentlyAdded(RError)
    case failedUpNext(RError)
    
    public var next: (any RError)? {
        switch self {
        case .failedRecentlyAdded(let err), .failedUpNext(let err):
            return err
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .failedRecentlyAdded: return "Failed to get recently added list"
        case .failedUpNext: return "Failed to get up next list"
        }
    }
}

public enum LibraryErrors: RError {
    /// Failed ot get library metadata
    case gettingLibraries(RError)
    /// Failed to get library media. The `String` value is the name/id of the library
    case gettingLibraryMedia(RError, String)
    /// Failed to get seasons. The `String` value is the name/id of the library
    case gettingSeasons(RError, String)
    /// Failed to get a single season. The `String` value is the ID of the season
    case gettingSeason(RError, String)
    /// Failed to get the media for a season. The `String` value is the ID of the season
    case gettingSeasonMedia(RError, String)
    /// The library failed for some unknown reason.
    case unknown(String)
    
    public var next: (RError)? {
        switch self {
        case .gettingLibraries(let next), .gettingLibraryMedia(let next, _), .gettingSeasons(let next, _), .gettingSeason(let next, _):
            return next
        case .gettingSeasonMedia(let next, _):
            return next
        case .unknown:
            return nil
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .gettingLibraries: return "Failed to get library data"
        case .gettingLibraryMedia(_, let name): return "Failed to get library content for library \(name)"
        case .gettingSeasons(_, let name): return "Failed to get seasons for library \(name)"
        case .gettingSeason(_, let id): return "Failed to get the season with the ID \(id)"
        case .gettingSeasonMedia(_, let id): return "Failed to get the season media for the season \(id)"
        case .unknown(let name): return "The library \(name) has failed to setup."
        }
    }
}

/// Errors related to logging in
public enum AccountErrors: RError {
    /// Failed to log into server.
    case loginFailed(RError)
    /// Failed to get the server's version,
    case serverVersionFailed(RError)
    
    public var next: (RError)? {
        switch self {
        case .loginFailed(let next), .serverVersionFailed(let next):
            return next
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .loginFailed:
            return "Login failed"
        case .serverVersionFailed:
            return "Failed to get server version"
        }
    }
}

enum JellyfinNetworkErrors: RError {
    case playbackUpdateFailed(RError)
    
    var next: (any RError)? {
        switch self {
        case .playbackUpdateFailed(let err):
            return err
        }
    }
    
    var errorDescription: String {
        switch self {
        case .playbackUpdateFailed: return "Failed to update playback status"
        }
    }
}
