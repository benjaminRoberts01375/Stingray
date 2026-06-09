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
        case .localUserID: return "localUserID"
        case .maxBitrate: return "maxBitrate"
        case .preference(let preference, let userID): return "preference-\(preference.rawValue)-\(userID)"
        }
    }
}

public enum PreferenceKey: String {
    case pin
}

/// A protocol for abstracting access to local storage via key-value pairs
public protocol BasicStorageProtocol {
    /// Set a `String` into storage
    /// - Parameters:
    ///   - key: Location the `String` should be saved to
    ///   - value: The `String` itself
    func setString(_ key: StorageKeys, value: String)
    /// Set a `Bool` into storage
    /// - Parameters:
    ///   - key: Location the `Bool` should be saved to
    ///   - value: The `Bool` itself
    func setBool(_ key: StorageKeys, value: Bool)
    /// Set a `Numeric` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `Numeric` value itself
    func setNumber<T: Numeric>(_ key: StorageKeys, value: T?)
    /// Set a `RawRepresentable` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `RawRepresentable` value itself
    func setRepresentable<T: RawRepresentable>(_ key: StorageKeys, value: T)
    /// Set a `Codable` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `Codable` value itself
    func setObject<T: Codable>(_ key: StorageKeys, value: T)
    /// Delete a key from storage
    /// - Parameter key: The key to delete
    func delete(_ key: StorageKeys)
    /// Get a `String` if it's available
    /// - Parameter key: Location of the desired `String`
    /// - Returns: The `String` if it was found
    func getString(_ key: StorageKeys) -> String?
    /// Get a `[String]` if it's available
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `[String]` itself
    func setStringArray(_ key: StorageKeys, value: [String]?)
    /// Get an array of `String` values if available
    /// - Parameter key: Location of the desired array
    /// - Returns: The array of `String` values if it was found
    func getStringArray(_ key: StorageKeys) -> [String]?
    /// Get a number if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The `Numeric` value if it was found
    func getNumber<T: Numeric>(_ key: StorageKeys) -> T?
    /// Get a `RawRepresentable` value if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The `RawRepresentable` value if it was found
    func getRepresentable<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String
    /// Get an object that can be decoded if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The decoded object
    func getObject<T: Decodable>(_ key: StorageKeys) -> T?
    /// Allows setting the key to be saved both locally and in the cloud
    /// - Parameters:
    ///   - key: Key to update the value for
    ///   - local: Should this key only be saved locally or not
    func setKeyIsLocal(_ key: StorageKeys, local: Bool)
    /// Checks to see if the key is meant to be saved locally or in the cloud as well
    /// - Parameter key: Key to check
    /// - Returns: If the key is only stored locally or not
    func getKeyIsLocal(_ key: StorageKeys) -> Bool
}

/// Stores data locally and in the cloud
public final class HybridBasicStorage: BasicStorageProtocol {
    /// How storage gets synced
    private let cloudStore: NSUbiquitousKeyValueStore
    /// Data that remains local
    private let defaults: UserDefaults
    
    /// Sets up storage for local and cloud syncing
    public init() throws(BasicStorageErrors) {
        // Setup local storage
        guard let defaults = UserDefaults(suiteName: "group.com.benlab.stingray") // Use a group to sync with extensions (ex TopShelf)
        else { throw .userDefaultsSetup }
        self.defaults = defaults
        
        // Setup cloud storage
        self.cloudStore = NSUbiquitousKeyValueStore.default // Setup key-value store
        self.cloudStore.synchronize() // Get the latest data from iCloud
    }
    
    public func getKeyIsLocal(_ key: StorageKeys) -> Bool {
        if Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? false { // iCloud often isn't fast enough for the TopShelf
            return true
        }
        return self.defaults.bool(forKey: "Local\(key.rawValue)")
    }
    
    public func setKeyIsLocal(_ key: StorageKeys, local: Bool) {
        self.defaults.set(local, forKey: "Local\(key.rawValue)")
    }
    
    /// Directly interfaces with storage systems to set values.
    /// This is intended to be called by other functions that filter types to be known-safe during runtime
    /// - Parameters:
    ///   - key: Location to save values
    ///   - value: Value to save
    private func simpleSet(_ key: StorageKeys, value: Any?) {
        if !self.getKeyIsLocal(key) { self.cloudStore.set(value, forKey: key.rawValue) }
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func setString(_ key: StorageKeys, value: String) { self.simpleSet(key, value: value) }
    
    public func setStringArray(_ key: StorageKeys, value: [String]?) { self.simpleSet(key, value: value) }
    
    public func setBool(_ key: StorageKeys, value: Bool) { self.simpleSet(key, value: value) }
    
    public func setNumber<T: Numeric>(_ key: StorageKeys, value: T?) { self.simpleSet(key, value: value) }
    
    public func setRepresentable<T: RawRepresentable>(_ key: StorageKeys, value: T) { self.simpleSet(key, value: value.rawValue) }
    
    public func setObject<T: Codable>(_ key: StorageKeys, value: T) {
        guard let data = try? JSONEncoder().encode(value).base64EncodedString()
        else { return }
        self.simpleSet(key, value: data)
    }
    
    public func delete(_ key: StorageKeys) {
        self.defaults.removeObject(forKey: key.rawValue)
        if !self.getKeyIsLocal(key) { self.cloudStore.removeObject(forKey: key.rawValue) }
    }
    
    public func getString(_ key: StorageKeys) -> String? {
        let result: String?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.string(forKey: key.rawValue) }
        else { result = self.defaults.string(forKey: key.rawValue) }
        return result == "" ? nil : result
    }
    
    public func getStringArray(_ key: StorageKeys) -> [String]? {
        let result: [String]?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.array(forKey: key.rawValue) as? [String] }
        else { result = self.defaults.stringArray(forKey: key.rawValue) }
        return result?.isEmpty ?? false ? nil : result
    }
    
    public func getNumber<T: Numeric>(_ key: StorageKeys) -> T? {
        let result: Any?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.object(forKey: key.rawValue) }
        else { result = self.defaults.object(forKey: key.rawValue) }
        
        return result as? T
    }
    
    public func getRepresentable<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String {
        let raw: String? = self.getString(key) // We get empty safety by reusing our functions
        if let raw { return T(rawValue: raw) }
        else { return nil }
    }
    
    public func getObject<T: Decodable>(_ key: StorageKeys) -> T? {
        guard let encoded: String = self.getString(key),
              let data: Data = Data(base64Encoded: encoded)
        else { return nil }
        
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
