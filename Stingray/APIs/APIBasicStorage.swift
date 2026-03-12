//
//  BasicStorageProtocol.swift
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
    
    /// A string representation of the enum
    public var rawValue: String {
        switch self {
        case .defaultStreamingUserID: return "defaultStreamingUserID"
        case .userIDs: return "userIDs"
        case .user(let id): return "user\(id)"
        case .userSwitchingMethod: return "userSwitchingMethod"
        }
    }
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
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    ///   - value: Text to set
    func setString(_ key: StorageKeys, value: String)
    /// Deletes a `String` from storage
    /// - Parameters:
    ///   - key: Key the string resides at.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func deleteString(_ key: StorageKeys)
    /// Get a `[String]` from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found `[String]`
    func getStringArray(_ key: StorageKeys) -> [String]
    /// Set a `[String]` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Array to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key
    func setStringArray(_ key: StorageKeys, value: [String])
    /// Get a URL from local storage
    /// - Parameters:
    ///   - key: The key where the data might be stored.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    /// - Returns: The found `URL`.
    func getURL(_ key: StorageKeys) -> URL?
    /// Set a `URL` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: `URL` to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func setURL(_ key: StorageKeys, value: URL?)
    /// Set a `Boolean` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: `Boolean` to set.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func setBool(_ key: StorageKeys, value: Bool)
    /// Get a `Boolean` from local storage
    /// - Parameter key: The key where the data might be stored.
    /// - Returns: The found `Boolean`.
    ///   - id: Unique ID for saving multiple versions of this value at this key.
    func getBool(_ key: StorageKeys) -> Bool
    /// Store data in a place compatible with the Top Shelf.
    /// - Parameters:
    ///   - key: The key where data is to be stored.
    ///   - value: Data to store.
    func setTopShelfString(_ key: StorageKeys, value: String)
    /// Retrieve data from a location compatible with the Top Shelf
    /// - Parameter key: Where the value may be stored.
    /// - Returns: Found data if available
    func getTopShelfString(_ key: StorageKeys) -> String?
    /// Sets or updates secured data via key/value pairs
    /// - Parameters:
    ///   - key: The key where the data is to be stored.
    ///   - data: Data to store at the given key.
    /// - Throws: Throws `BasicStorageErrors` if the data cannot be formatted, or the secure storage also throws an error.
    func setSecureData<E: Codable>(_ key: StorageKeys, data: E) throws(BasicStorageErrors)
    /// Reads secure data from storage. Data is automatically formatted via the generic.
    /// - Parameter key: Data to lookup
    /// - Returns: Formatted data
    /// - Throws: Throws `BasicStorageErrors` if the data is not formatted correct, cannot be found, or other reasons.
    func getSecureData<D: Decodable>(_ key: StorageKeys) throws(BasicStorageErrors) -> D
    /// Deletes a key/value pair from secure storage.
    /// - Parameter key: Key to delete.
    /// - Throws: Throws a `BasicStorageErrors` if the secure data method also throws an error.
    func deleteSecureData(_ key: StorageKeys) throws(BasicStorageErrors)
}

final class DefaultsBasicStorage: BasicStorageProtocol {
    private let defaults: UserDefaults
    private let topShelf: UserDefaults?
    
    init() {
        self.defaults = UserDefaults.standard
        self.topShelf = UserDefaults(suiteName: "group.com.benlab.stingray")
    }
    
    func getString(_ key: StorageKeys) -> String? {
        let key = defaults.string(forKey: key.rawValue)
        if key == "" { return nil } // Little extra safety
        return key
    }
    
    func setString(_ key: StorageKeys, value: String) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getURL(_ key: StorageKeys) -> URL? {
        return URL(string: defaults.string(forKey: key.rawValue) ?? "")
    }
    
    func setURL(_ key: StorageKeys, value: URL?) {
        defaults.set(value?.absoluteString ?? "", forKey: key.rawValue)
    }
    
    func getBool(_ key: StorageKeys) -> Bool {
        return defaults.bool(forKey: key.rawValue)
    }
    
    func setBool(_ key: StorageKeys, value: Bool) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getStringArray(_ key: StorageKeys) -> [String] {
        return defaults.stringArray(forKey: key.rawValue) ?? []
    }
    
    func setStringArray(_ key: StorageKeys, value: [String]) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func deleteString(_ key: StorageKeys) {
        defaults.removeObject(forKey: key.rawValue)
    }
    
    func setTopShelfString(_ key: StorageKeys, value: String) {
        self.topShelf?.set(value, forKey: key.rawValue)
    }
    
    func getTopShelfString(_ key: StorageKeys) -> String? {
        let foundData = self.topShelf?.string(forKey: key.rawValue)
        if foundData == "" { return nil } // Little extra safety
        return foundData
    }
    
    func setSecureData<E: Codable>(_ key: StorageKeys, data: E) throws(BasicStorageErrors) {
        let encodedData: Data
        do { encodedData = try JSONEncoder().encode(data) }
        catch { throw BasicStorageErrors.encodingFailed(JSONError.failedJSONEncode(key.rawValue), key.rawValue) }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecValueData: encodedData,
            kSecAttrService: "com.benlab.Stingray",
            kSecAttrAccessGroup: Self.keychainAccessGroup(),
            kSecUseUserIndependentKeychain: true
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { // Entry already exists at key, update it instead
            let lookupQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key.rawValue,
                kSecAttrService: "com.benlab.Stingray",
                kSecAttrAccessGroup: Self.keychainAccessGroup(),
                kSecUseUserIndependentKeychain: true
            ]
            let updatedData: [CFString: Any] = [kSecValueData: encodedData]
            let updateStatus = SecItemUpdate(lookupQuery as CFDictionary, updatedData as CFDictionary)
            if updateStatus != errSecSuccess { throw BasicStorageErrors.updateFailed(updateStatus, key.rawValue) } // Failed to save
        }
        else if status != errSecSuccess { throw BasicStorageErrors.saveFailed(status, key.rawValue) } // Entry failed to succeed
    }
    
    func getSecureData<D: Decodable>(_ key: StorageKeys) throws(BasicStorageErrors) -> D {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.benlab.Stingray",
            kSecAttrAccessGroup: Self.keychainAccessGroup(),
            kSecAttrAccount: key.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseUserIndependentKeychain: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound { throw BasicStorageErrors.notFound(key.rawValue) }
        else if status != errSecSuccess { throw BasicStorageErrors.readError(status, key.rawValue) }
        
        // Convert to Data type if possible
        guard let data = result as? Data
        else { throw BasicStorageErrors.unexpectedData(key.rawValue) }
        // Decode Data into JSON
        do { return try JSONDecoder().decode(D.self, from: data) }
        catch { throw BasicStorageErrors.decodingFailed(JSONError.failedJSONDecode(key.rawValue, error), key.rawValue) }
    }
    
    func deleteSecureData(_ key: StorageKeys) throws(BasicStorageErrors) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "com.benlab.Stingray",
            kSecAttrAccessGroup: Self.keychainAccessGroup(),
            kSecUseUserIndependentKeychain: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw BasicStorageErrors.deleteFailed(status, key.rawValue)
        }
    }
    
    static func keychainAccessGroup() -> String {
        guard let teamID = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String else {
            fatalError("Could not read AppIdentifierPrefix from bundle")
        }
        // teamID already includes the trailing dot e.g. "XXXXXXXXXX."
        return "\(teamID)com.benlab.stingray"
    }
}
