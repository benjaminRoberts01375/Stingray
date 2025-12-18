//
//  BasicStorageProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public enum StorageKeys: String {
    case defaultUserID = "defaultUserID"
    case userIDs = "userIDs"
    case user = "user"
}

/// A protocol for abstracting access to local storage via key-value pairs
public protocol BasicStorageProtocol {
    /// Get a `String` from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found string
    func getString(_ key: StorageKeys, id: String) -> String?
    /// Set a `String` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    ///   - value: Text to set
    func setString(_ key: StorageKeys, id: String, value: String)
    /// Deletes a `String` from storage
    /// - Parameters:
    ///   - key: Key the string resides at.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func deleteString(_ key: StorageKeys, id: String)
    /// Get a `[String]` from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found `[String]`
    func getStringArray(_ key: StorageKeys, id: String) -> [String]
    /// Set a `[String]` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Array to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key
    func setStringArray(_ key: StorageKeys, id: String, value: [String])
    /// Get a URL from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found `URL`.
    func getURL(_ key: StorageKeys, id: String) -> URL?
    /// Set a `URL` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: `URL` to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func setURL(_ key: StorageKeys, id: String, value: URL?)
    /// Set a `Boolean` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: `Boolean` to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func setBool(_ key: StorageKeys, id: String, value: Bool)
    /// Get a `Boolean` from local storage
    /// - Parameter key: The key where the data might be stored.
    /// - Returns: The found `Boolean`.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func getBool(_ key: StorageKeys, id: String) -> Bool
}

final class DefaultsBasicStorage: BasicStorageProtocol {
    private let defaults: UserDefaults
    
    init() {
        // Use the shared container instead of standard defaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.benlab.stingray") {
            print("Setting up user defaults with suite name")
            self.defaults = sharedDefaults
        } else {
            // Fallback to standard defaults if app group isn't configured
            print("Setting up generic user defaults")
            self.defaults = UserDefaults.standard
        }
    }
    
    func getString(_ key: StorageKeys, id: String) -> String? {
        return defaults.string(forKey: key.rawValue + id)
    }
    
    func setString(_ key: StorageKeys, id: String, value: String) {
        defaults.set(value, forKey: key.rawValue + id)
    }
    
    func getURL(_ key: StorageKeys, id: String) -> URL? {
        return URL(string: defaults.string(forKey: key.rawValue + id) ?? "")
    }
    
    func setURL(_ key: StorageKeys, id: String, value: URL?) {
        defaults.set(value?.absoluteString ?? "", forKey: key.rawValue + id)
    }
    
    func getBool(_ key: StorageKeys, id: String) -> Bool {
        return defaults.bool(forKey: key.rawValue + id)
    }
    
    func setBool(_ key: StorageKeys, id: String, value: Bool) {
        defaults.set(value, forKey: key.rawValue + id)
    }
    
    func getStringArray(_ key: StorageKeys, id: String) -> [String] {
        return defaults.stringArray(forKey: key.rawValue + id) ?? []
    }
    
    func setStringArray(_ key: StorageKeys, id: String, value: [String]) {
        defaults.set(value, forKey: key.rawValue + id)
    }
    
    func deleteString(_ key: StorageKeys, id: String) {
        defaults.removeObject(forKey: key.rawValue + id)
    }
}
