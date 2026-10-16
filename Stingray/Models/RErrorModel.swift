//
//  RErrorModel.swift
//  Stingray
//
//  Created by Ben Roberts on 1/24/26.
//

import StoreKit

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
            return "The unwrapped JSON value was unexpected"
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
    case librarySetupFailed(Error)
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
    /// Unable to get the library version of the server
    case serverVersionFailed(RError?)

    public var errorDescription: String {
        switch self {
        case .librarySetupFailed: return "Failed to get any library data"
        case .initFailed: return "Failed to create a library"
        case .badAddress: return "Bad address to server"
        case .noToken: return "No API token available"
        case .badDefaultUser: return "Creation of a default user failed"
        case .noDefaultUser: return "No default user is available"
        case .serverVersionFailed: return "Failed to get the server's version"
        }
    }

    public var next: (any RError)? {
        switch self {
        case .initFailed(let err):
            if let rError = err as? StreamingServiceErrors { return rError }
            return nil
        case .badAddress, .noDefaultUser, .noToken, .librarySetupFailed: return nil
        case .badDefaultUser(let err): return err
        case .serverVersionFailed(let err): return err
        }
    }
}

/// Different ways the Advanced Network can error.
public enum AdvancedNetworkErrors: RError {
    /// Failed to get recently added media.
    case failedRecentlyAdded(RError)
    /// Failed to get "up next" (what to watch next).
    case failedUpNext(RError)
    /// Failed to get special features for a particular `MediaProtocol`.
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
    /// Failed to get library metadata
    case gettingLibraries(RError)
    /// Failed to get library media. The `String` value is the name/id of the library
    case gettingLibraryMedia(RError, String)
    /// Failed to get a single season. The `String` value is the ID of the season
    case gettingSeason(RError, String)
    /// Failed to get any of the seasons. The string is the media ID
    case gettingSeasons(RError?, String)
    /// The task group used to manage season collection threw an error
    case seasonTaskGroup(Error)
    /// Failed to get the special features for a piece of media. The `String` value is the title of the media
    case specialFeaturesFailed(RError?, String)
    /// The library failed for some unknown reason.
    case unknown(String)

    public var next: (RError)? {
        switch self {
        case .gettingLibraries(let next), .gettingLibraryMedia(let next, _), .gettingSeason(let next, _): return next
        case .specialFeaturesFailed(let next, _), .gettingSeasons(let next, _): return next
        case .unknown, .seasonTaskGroup: return nil
        }
    }

    public var errorDescription: String {
        switch self {
        case .gettingLibraries: return "Failed to get library data"
        case .gettingLibraryMedia(_, let name): return "Failed to get library content for library \(name)"
        case .gettingSeason(_, let id): return "Failed to get the season with the ID \(id)"
        case .gettingSeasons(_, let id): return "Failed to get any of the seasons for Media ID: \(id)"
        case .seasonTaskGroup: return "A group of seasons failed to load"
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
public enum JellyfinNetworkErrors: RError {
    /// Failed to update the playback position.
    case playbackUpdateFailed(RError)

    public var next: (any RError)? {
        switch self {
        case .playbackUpdateFailed(let err):
            return err
        }
    }

    public var errorDescription: String {
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
    /// `UserDefaults` could not be opened for the shared app group, so nothing can be persisted
    case userDefaultsSetup

    public var next: (any RError)? {
        switch self {
        case .userDefaultsSetup: return nil
        }
    }

    public var errorDescription: String {
        switch self {
        case .userDefaultsSetup: return "Failed to setup User Defaults with App Group"
        }
    }
}

/// Errors during app setup
public enum SetupErrors: RError {
    /// Permanent storage failed to open. Stingray stops rather than risk writing over the user's existing data
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

/// Errors relating to the Jellyfin Quick Connect feature
public enum QuickConnectErrors: RError {
    /// Could not connect to the Jellyfin server at all
    case initialConnectionFailed(RError)
    /// Failed to login user
    case loginFailed(RError)
    /// Failed to get Quick Connect codes
    case quickConnectCodesFailed(RError)
    /// Error checking Quick Connect code status with server
    case authFailed(RError)
    /// Failed to check if Quick Connect is enabled
    case isEnabled(RError)

    /// Failed to poll the server for whether the user has entered the Quick Connect code yet
    case statusFailedtoFetch(RError)

    public var next: (any RError)? {
        switch self {
        case .initialConnectionFailed(let err): return err
        case .loginFailed(let err): return err
        case .authFailed(let err): return err
        case .quickConnectCodesFailed(let err): return err
        case .isEnabled(let err): return err
        case .statusFailedtoFetch(let err): return err
        }
    }

    public var errorDescription: String {
        switch self {
        case .initialConnectionFailed: return "Failed to connect to the Jellyfin server"
        case .loginFailed: return "Login failed despite good Quick Connect code"
        case .authFailed: return "Failed to check if Quick Connect code was used"
        case .quickConnectCodesFailed: return "Failed to get Quick Connect code"
        case .isEnabled: return "Failed to check if Quick Connect is available"
        case .statusFailedtoFetch: return "Failed to check if Quick Connect has been setup on the Jellyfin server"

        }
    }
}

/// Errors for in app purchases
public enum StoreErrors: RError {
    /// StoreKit rejected the purchase attempt
    case purchaseFailed(Product, Error)
    /// StoreKit reported a `PurchaseResult` case that did not exist when this was written
    case purchasesUpdated
    /// The transaction came back unverified, meaning its signature could not be trusted
    case tamperedPurchase(Product, Error)
    /// The supporter product was missing from an otherwise successful product fetch
    case productUnavailable
    /// The product list could not be fetched from App Store Connect at all
    case productsUnavailable(Error)
    /// A purchase was attempted before the product list finished loading
    case productsStillLoading

    public var next: (any RError)? { nil }

    public var errorDescription: String {
        switch self {
        case .purchaseFailed(let product, let err): return "Failed to purchase \(product.id): \(err.localizedDescription)"
        case .purchasesUpdated: return "Apple changed the purchases API and added a case"
        case .tamperedPurchase(let product, let err): return "Purchasing \(product.id) could not be verified: \(err.localizedDescription)"
        case .productUnavailable: return "This product is unavailable"
        case .productsUnavailable(let err): return "All products are unavailable: \(err.localizedDescription)"
        case .productsStillLoading: return "Products are still loading"
        }
    }
}
