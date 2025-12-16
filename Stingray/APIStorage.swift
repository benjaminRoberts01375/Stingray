//
//  BasicStorageProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public enum BasicNetworkKeys: String {
    case serverURL = "serverURL"
    case usersName = "usersName"
    case userID = "userID"
    case sessionID = "sessionID"
    case accessToken = "accessToken"
    case serverID = "serverID"
    case defaultUserID = "defaultUserID"
}

/// A protocol for abstracting access to local storage via key-value pairs
public protocol BasicStorageProtocol {
    /// Get a `String` from local storage
    /// - Parameter key: The key where the data might be stored
    /// - Returns: The found string
    func getString(_ key: BasicNetworkKeys, id: String) -> String?
    /// Set a `String` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored
    ///   - value: Text to set
    func setString(_ key: BasicNetworkKeys, id: String, value: String)
    /// Get a URL from local storage
    /// - Parameter key: The key where the data might be stored
    /// - Returns: The found `URL`
    func getURL(_ key: BasicNetworkKeys, id: String) -> URL?
    /// Set a `URL` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored
    ///   - value: `URL` to set
    func setURL(_ key: BasicNetworkKeys, id: String, value: URL?)
    /// Set a `Boolean` into local storage
    /// - Parameters:
    ///   - key: The key where data is to be stored
    ///   - value: `Boolean` to set
    func setBool(_ key: BasicNetworkKeys, id: String, value: Bool)
    /// Get a `Boolean` from local storage
    /// - Parameter key: The key where the data might be stored
    /// - Returns: The found `Boolean`
    func getBool(_ key: BasicNetworkKeys, id: String) -> Bool
}

/// A protocol for abstracting advanced storage actions
public protocol AdvancedStorageProtocol {
    /// Get the streaming service URL from storage
    /// - Returns: The server's URL
    func getServerURL() -> URL?
    /// Set the streaming service URL in storage
    /// - Parameter url: URL to set
    func setServerURL(_ url: URL)
    /// Get the user's name from storage
    /// - Returns: The user's name
    func getUsersName() -> String?
    /// Set the user's name into storage
    /// - Parameter name: The user's name
    func setUsersName(_ name: String?)
    /// Get the userID from storage
    /// - Returns: The userID
    func getUserID() -> String?
    /// Set the userID into storage
    /// - Parameter id: The userID
    func setUserID(_ id: String?)
    /// Get the sessionID from storage
    /// - Returns: The sessionID
    func getSessionID() -> String?
    /// Set the sessionID into storage
    /// - Parameter id: The sessionID
    func setSessionID(_ id: String?)
    /// Get the server access token from storage
    /// - Returns: The access token
    func getAccessToken() -> String?
    /// Set the server access token into storage
    /// - Parameter token: The access token
    func setAccessToken(_ token: String?)
    /// Get the serverID from storage
    /// - Returns: The serverID
    func getServerID() -> String?
    /// Set the serverID into storage
    /// - Parameter id: The serverID
    func setServerID(_ id: String?)
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
    
    func getString(_ key: BasicNetworkKeys, id: String) -> String? {
        return defaults.string(forKey: key.rawValue + id)
    }
    
    func setString(_ key: BasicNetworkKeys, id: String, value: String) {
        defaults.set(value, forKey: key.rawValue + id)
    }
    
    func getURL(_ key: BasicNetworkKeys, id: String) -> URL? {
        return URL(string: defaults.string(forKey: key.rawValue + id) ?? "")
    }
    
    func setURL(_ key: BasicNetworkKeys, id: String, value: URL?) {
        defaults.set(value?.absoluteString ?? "", forKey: key.rawValue + id)
    }
    
    func getBool(_ key: BasicNetworkKeys, id: String) -> Bool {
        return defaults.bool(forKey: key.rawValue + id)
    }
    
    func setBool(_ key: BasicNetworkKeys, id: String, value: Bool) {
        defaults.set(value, forKey: key.rawValue + id)
    }
}

enum FailedToInitializeAdvancedStorage: Error {
    case noUserID
    case noServerID
}

final class DefaultsAdvancedStorage: AdvancedStorageProtocol {
    var storage: BasicStorageProtocol
    let activeUserID: String
    let activeServerID: String
    
    init(storage: BasicStorageProtocol, userID: String? = nil, serverID: String? = nil) throws {
        self.storage = storage
        
        guard let userID = userID ?? storage.getString(.defaultUserID, id: "") else { throw FailedToInitializeAdvancedStorage.noUserID}
        self.activeUserID = userID
        
        guard let serverID = serverID ?? storage.getString(.serverID, id: userID) else { throw FailedToInitializeAdvancedStorage.noServerID }
        self.activeServerID = serverID
    }
    
    func getServerURL() -> URL? {
        return storage.getURL(.serverURL, id: activeServerID)
    }
    func setServerURL(_ url: URL) {
        storage.setURL(.serverURL, id: activeServerID, value: url)
    }
    
    func getUsersName() -> String? {
        return storage.getString(.usersName, id: activeUserID)
    }
    func setUsersName(_ name: String?) {
        storage.setString(.usersName, id: activeUserID, value: name ?? "")
    }
    
    func getUserID() -> String? {
        return storage.getString(.userID, id: activeUserID)
    }
    func setUserID(_ id: String?) {
        storage.setString(.userID, id: activeUserID, value: id ?? "")
    }
    
    func getSessionID() -> String? {
        return storage.getString(.sessionID, id: activeUserID)
    }
    func setSessionID(_ id: String?) {
        storage.setString(.sessionID, id: activeUserID, value: id ?? "")
    }
    
    func getAccessToken() -> String? {
        return storage.getString(.accessToken, id: activeUserID)
    }
    func setAccessToken(_ token: String?) {
        storage.setString(.accessToken, id: activeUserID, value: token ?? "")
    }
    
    func getServerID() -> String? {
        return storage.getString(.serverID, id: activeUserID)
    }
    
    func setServerID(_ id: String?) {
        storage.setString(.serverID, id: activeUserID, value: id ?? "")
    }
}
