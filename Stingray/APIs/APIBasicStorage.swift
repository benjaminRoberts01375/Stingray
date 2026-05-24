//
//  APIBasicStorage.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation
import Security

/// Available keys for interacting with the permanent storage.
public enum StorageKeys {
    /// Active user
    case defaultStreamingUserID
    /// Key for all available userIDs
    case userIDs
    /// The user and userID to modify
    case user(String)
    /// A setting for how/when users should be switched
    case userSwitchingMethod
    /// Internal: Database version tracking
    case version
    /// Link a tvOS user to a Jellyfin user
    case linkUser(String)
    /// A unique identifier for a tvOS user
    case localUserID
    /// A unique ID for the maximum bitrate option
    case maxBitrate
    /// Modifies a preference for a given UserID
    case preference(PreferenceKey, String)
    
    /// A string representation of the enum
    public var rawValue: String {
        switch self {
        case .defaultStreamingUserID: return "defaultStreamingUserID"
        case .userIDs: return "userIDs"
        case .user(let id): return "user\(id)"
        case .userSwitchingMethod: return "userSwitchingMethod"
        case .version: return "db-version"
        case .linkUser(let id): return "linkUser-\(id)"
        case .localUserID: return "localUserID"
        case .maxBitrate: return "maxBitrate"
        case .preference(let preference, let userID): return "preference-\(preference.rawValue)-\(userID)"
        }
    }
}

public enum PreferenceKey: String {
    case pin
}

public enum DBType: String {
    /// The global keychain
    case keychain
    /// The database meant to share data to the top shelf
    case topShelf
    /// The database that changes with the tvOS user
    case perTVOSUserDefaults
}

/// A protocol for abstracting access to local storage via key-value pairs
public protocol BasicStorageProtocol {
    /// Get a `String` from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found string
    func getString(_ key: StorageKeys) -> String?
    /// Set a `String` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Text to set
    func setString(_ key: StorageKeys, value: String)
    /// Set a `[String]` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored
    ///   - value: Data to set
    func setStringArray(_ key: StorageKeys, value: [String]?)
    /// Get `[String]` from local storage
    /// - Parameter key: Where to get the data from
    /// - Returns: The available data
    func getStringArray(_ key: StorageKeys) -> [String]?
    /// Set an `Int` into local storage. Returns 0 if the value does not exist in storage.
    /// - Parameter key: The key where data is to be stored
    /// - Returns: The found `Int`
    func getInt(_ key: StorageKeys) -> Int
    /// Set an `Int` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Text to set
    func setInt(_ key: StorageKeys, value: Int?)
    /// Deletes a `String` from storage
    /// - Parameters:
    ///   - key: Key the string resides at.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func deleteString(_ key: StorageKeys)
    /// Set an enum type to local storage
    /// - Parameters:
    ///   - key: Where to store the enum
    ///   - value: Value to store
    func setEnum<T: RawRepresentable>(_ key: StorageKeys, value: T)
    /// Get an enum type from local storage
    /// - Parameter key: Where the data is stored
    /// - Returns: Found value if available
    func getEnum<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String
    /// Store any `Codable` object into local storage.
    /// - Note: This is less performant due to the reliance on encoding and decoding, thus should be avoided if possible
    /// - Parameters:
    ///   - key: Location to store data
    ///   - value: Data to store
    func setObject<T: Codable>(_ key: StorageKeys, value: T)
    /// Get any `Decodable` object from local storage
    /// - Note: This is less performant due to the reliance on encoding and decoding, thus should be avoided if possible
    /// - Parameter key: Location where the data may be stored
    /// - Returns: Found value if available
    func getObject<T: Decodable>(_ key: StorageKeys) -> T?
    /// Store data in a place compatible with the Top Shelf.
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Data to store.
    func setTopShelfString(_ key: StorageKeys, value: String)
    /// Retrieve data from a location compatible with the Top Shelf
    /// - Parameter key: Where the value may be stored.
    /// - Returns: Found data if available
    func getTopShelfString(_ key: StorageKeys) -> String?
}

public final class DefaultsBasicStorage: BasicStorageProtocol {
    private let defaults: UserDefaults
    public static let dbVersion = "2"
    
    public init() throws(BasicStorageErrors) {
        guard let defaults = UserDefaults(suiteName: "group.com.benlab.stingray")
        else { throw .userDefaultsSetup }
        self.defaults = defaults
    }
    
    public func getString(_ key: StorageKeys) -> String? {
        let key = defaults.string(forKey: key.rawValue)
        if key == "" { return nil } // Little extra safety
        return key
    }
    
    public func setString(_ key: StorageKeys, value: String) {
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func getStringArray(_ key: StorageKeys) -> [String]? {
        return self.defaults.stringArray(forKey: key.rawValue)
    }
    
    public func setStringArray(_ key: StorageKeys, value: [String]?) {
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func getInt(_ key: StorageKeys) -> Int {
        return self.defaults.integer(forKey: key.rawValue)
    }
    
    public func setInt(_ key: StorageKeys, value: Int?) {
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func deleteString(_ key: StorageKeys) {
        self.defaults.removeObject(forKey: key.rawValue)
    }
    
    public func setTopShelfString(_ key: StorageKeys, value: String) {
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func getTopShelfString(_ key: StorageKeys) -> String? {
        let foundData = self.defaults.string(forKey: key.rawValue)
        if foundData == "" { return nil } // Little extra safety
        return foundData
    }
    
    public func setEnum<T: RawRepresentable>(_ key: StorageKeys, value: T) {
        guard let value = value.rawValue as? String
        else { return }
        self.setString(key, value: value)
    }
    
    public func getEnum<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String {
        guard let raw = self.getString(key)
        else { return nil }
        return T(rawValue: raw)
    }
    
    public func setObject<T: Codable>(_ key: StorageKeys, value: T) {
        guard let data = try? JSONEncoder().encode(value).base64EncodedString()
        else { return }
        self.setString(key, value: data)
    }
    
    public func getObject<T: Decodable>(_ key: StorageKeys) -> T? {
        guard let json = self.getString(key),
              let data = Data(base64Encoded: json)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
