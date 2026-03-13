//
//  RError.swift
//  Stingray
//
//  Created by Ben Roberts on 1/24/26.
//

import Foundation

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
        Log.warning(total)
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
        Log.warning(total)
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
    static func overrideNetErrorMessage(netErr: NetworkError, httpProtocol: HttpProtocol) -> String {
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

enum HttpProtocol: String, CaseIterable {
    case http = "http"
    case https = "https"
}

/// Different ways JSON can have an error.
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
        case .failedJSONDecode(_, let err):
            if let rError = err as? RError { return rError }
            return nil
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

/// Different ways creating Media can have an error.
public enum MediaError: RError {
    /// The media is an unknown type. The `String` value is the type attempted to be made
    case unknownMediaType(String)
    
    public var errorDescription: String {
        switch self {
        case .unknownMediaType(let mediaType):
            return "Unknown media type \"\(mediaType)\""
        }
    }
    
    public var next: (any RError)? { nil }
}

/// Different ways a `StreamingServiceProtocol` can error out.
public enum StreamingServiceErrors: RError {
    /// Failed to get initial library data.
    case librarySetupFailed(RError?)
    /// Failed to create a streaming service object
    case initFailed(any Error)
    /// Address to the server was bad
    case badAddress
    /// No server API token
    case noToken
    /// User failed to be made
    case badDefaultUser(RError)
    /// No user is available
    case noDefaultUser
    
    public var errorDescription: String {
        switch self {
        case .librarySetupFailed: return "Failed to get library data"
        case .initFailed: return "Failed to create a library"
        case .badAddress: return "Bad address to server"
        case .noToken: return "No API token available"
        case .badDefaultUser: return "Creation of a default user failed"
        case .noDefaultUser: return "No default user is available"
        }
    }
    
    public var next: (any RError)? {
        switch self {
        case .librarySetupFailed(let err): return err
        case .initFailed(let err):
            if let rError = err as? StreamingServiceErrors { return rError }
            return nil
        case .badAddress, .noDefaultUser, .noToken: return nil
        case .badDefaultUser(let err): return err
        }
    }
}

/// Different ways the Advanced Network can error.
public enum AdvancedNetworkErrors: RError {
    /// Failed to get recently added media.
    case failedRecentlyAdded(RError)
    /// Failed to get "up next" (what to watch next).
    case failedUpNext(RError)
    /// Failed to get special features for a particular `MediaModelProtocol`.
    case failedSpecialFeatures(RError)
    
    public var next: (any RError)? {
        switch self {
        case .failedRecentlyAdded(let err), .failedUpNext(let err), .failedSpecialFeatures(let err):
            return err
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .failedRecentlyAdded: return "Failed to get recently added list"
        case .failedUpNext: return "Failed to get up next list"
        case .failedSpecialFeatures: return "Failed to get special features list"
        }
    }
}

/// Different ways a Library can error out while setting up.
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
    /// Failed to get the special features for a piece of media. The `String` value is the title of the media
    case specialFeaturesFailed(RError, String)
    /// The library failed for some unknown reason.
    case unknown(String)
    
    public var next: (RError)? {
        switch self {
        case .gettingLibraries(let next), .gettingLibraryMedia(let next, _), .gettingSeasons(let next, _), .gettingSeason(let next, _):
            return next
        case .gettingSeasonMedia(let next, _), .specialFeaturesFailed(let next, _):
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
        case .specialFeaturesFailed(_, let name): return "Failed to load the special features for \(name)"
        case .unknown(let name): return "The library \(name) has failed to setup."
        }
    }
}

/// Errors related to logging in.
public enum AccountErrors: RError {
    /// Failed to log into server.
    case loginFailed(RError?)
    /// Failed to get the server's version,
    case serverVersionFailed(RError)
    
    public var next: (RError)? {
        switch self {
        case .loginFailed(let next): return next
        case .serverVersionFailed(let next): return next
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

/// Different ways the Jellyfin server can have an error.
enum JellyfinNetworkErrors: RError {
    /// Failed to update the playback position.
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

/// `UserDefaults` errors
public enum UserDefaultsErrors: RError {
    /// Failed to create a UserDefaults object
    case FailedSetup
    
    public var next: (any RError)? { nil }
    
    public var errorDescription: String { "Failed to setup user defaults with suiteName" }
}

/// Errors for `DefaultsBasicStorage`
public enum BasicStorageErrors: RError {
    /// Failed to update an existing entry. The `String` value is the key used.
    case updateFailed(OSStatus, String)
    /// Failed to save a new entry. The `String` value is the key used.
    case saveFailed(OSStatus, String)
    /// Failed to encode provided type. The `String` value is the request key.
    case encodingFailed(RError, String)
    /// Failed to read data at the provided key. The `String` value is the request key.
    case decodingFailed(RError, String)
    /// Secure data returned an unexpected result. The `String` value is the request key.
    case unexpectedData(String)
    /// The requested data was not found in secure data. The `String` value is the request key.
    case notFound(String)
    /// An error occured when attempting to read from secure storage.
    case readError(OSStatus, String)
    /// Failed to delete data at the provided key
    case deleteFailed(OSStatus, String)
    /// Could not find the database's version
    case unknownDBVersion(Error)
    /// Could not set the version for the database
    case unableToSetDBVersion(String, Error)
    /// Unable to migrate the database from some version to another
    case unableToMigrateDB(String?, String, RError?)
    
    public var next: (any RError)? {
        switch self {
        case .updateFailed, .saveFailed, .deleteFailed, .unexpectedData, .readError, .notFound: return nil
        case .encodingFailed(let err, _), .decodingFailed(let err, _): return err
        case .unknownDBVersion: return nil
        case .unableToSetDBVersion: return nil
        case .unableToMigrateDB(_, _, let err): return err
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .updateFailed(let osStatus, let key):
            return "Failed to update secure data: \(SecCopyErrorMessageString(osStatus, nil) as String? ?? "Unknown") at '\(key)'"
        case .saveFailed(let osStatus, let key):
            return "Failed to save to secure data: \(SecCopyErrorMessageString(osStatus, nil) as String? ?? "Unknown") at '\(key)'"
        case .encodingFailed(_, let key):
            return "Failed to encode value for key '\(key)'"
        case .decodingFailed(_, let key):
            return "Failed decode value for key '\(key)'"
        case .unexpectedData(let key):
            return "Secure data returned something that was not of type Data at key '\(key)'"
        case .readError(let osStatus, let key):
            let message = SecCopyErrorMessageString(osStatus, nil) as String? ?? "of an unknown reason"
            return "Failed to read secure data at key '\(key)' because \(message)"
        case .notFound(let key):
            return "Secure data could not find the value at key '\(key)'"
        case .deleteFailed(let osStatus, let key):
            let message = SecCopyErrorMessageString(osStatus, nil) as String? ?? "of an unknown reason"
            return "Failed to delete secure data at key '\(key)' because \(message)"
        case .unknownDBVersion(let err):
            return "Unable to get the version of the database: \(err.localizedDescription)"
        case .unableToSetDBVersion(let newVersion, let err):
            return "Unable to set the version of the database to v\(newVersion): \(err.localizedDescription)"
        case .unableToMigrateDB(let vStart, let vEnd, _):
            return "Unable to migrate the database from v\(vStart ?? "Unknown"), to v\(vEnd)"
        }
    }
}

/// Errors during app setup
public enum SetupErrors: RError {
    case databaseError(RError)
    
    public var next: (any RError)? {
        switch self {
        case .databaseError(let error): return error
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .databaseError: return "Failed to setup databases. Stingray may be able to continue, but this protects your data"
        }
    }
}
