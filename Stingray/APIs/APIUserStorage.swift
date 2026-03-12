//
//  APIUserStorage.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation
import Security

/// Secure Keychain storage for authentication tokens
enum KeychainTokenStorage {
    private static let service = "com.benlab.stingray.tokens"

    /// Store access token and session ID securely in the Keychain
    static func storeTokens(accessToken: String, sessionID: String, forUserID userID: String) {
        let tokenData: [String: String] = [
            "accessToken": accessToken,
            "sessionID": sessionID
        ]
        guard let data = try? JSONEncoder().encode(tokenData) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Retrieve tokens from the Keychain
    static func getTokens(forUserID userID: String) -> (accessToken: String, sessionID: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let tokenData = try? JSONDecoder().decode([String: String].self, from: data),
              let accessToken = tokenData["accessToken"],
              let sessionID = tokenData["sessionID"]
        else { return nil }

        return (accessToken, sessionID)
    }

    /// Delete tokens from the Keychain
    static func deleteTokens(forUserID userID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userID
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Local storage for modifying user-related data
public protocol UserStorageProtocol {
    /// Get all user IDs for all streaming services
    func getUserIDs() -> [String]
    /// Set all user IDs to an array of IDs
    /// - Parameter userIDs: User IDs to set
    func setUserIDs(_ userIDs: [String])
    /// Get the default user to use on startup
    /// - Returns: The default user ID
    func getDefaultUserID() -> String?
    /// Set the default user to use on startup
    /// - Parameter id: The default user ID
    func setDefaultUserID(id: String)
    /// Save a `User` into storage
    /// - Parameters:
    ///   - user: User to save
    func setUser(user: User)
    /// Get a `User` from storage
    /// - Parameter userID: ID of the user to find
    /// - Returns: The formatted `User`
    func getUser(userID: String) -> User?
    /// Deletes only user data
    /// - Parameter userID: ID of the user to remove
    func deleteUser(userID: String)
}

public final class UserStorage: UserStorageProtocol {
    let basicStorage: BasicStorageProtocol
    
    init(basicStorage: BasicStorageProtocol) { self.basicStorage = basicStorage }
    
    public func getUserIDs() -> [String] {
        return self.basicStorage.getStringArray(.userIDs, id: "")
    }
    
    public func setUserIDs(_ userIDs: [String]) {
        self.basicStorage.setStringArray(.userIDs, id: "", value: userIDs)
    }
    
    public func getDefaultUserID() -> String? {
        self.basicStorage.getString(.defaultUserID, id: "")
    }
    
    public func setDefaultUserID(id: String) {
        self.basicStorage.setString(.defaultUserID, id: "", value: id)
    }
    
    public func setUser(user: User) {
        // Save tokens securely to Keychain
        switch user.serviceType {
        case .Jellyfin(let jellyfin):
            KeychainTokenStorage.storeTokens(
                accessToken: jellyfin.accessToken,
                sessionID: jellyfin.sessionID,
                forUserID: user.id
            )
        }

        // Save user to UserDefaults with tokens stripped
        guard let encoded = try? JSONEncoder().encode(user),
              var jsonDict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        else { return }

        // Strip sensitive tokens from UserDefaults storage
        if var serviceType = jsonDict["serviceType"] as? [String: Any],
           var jellyfinData = serviceType["jellyfinData"] as? [String: Any] {
            jellyfinData["accessToken"] = ""
            jellyfinData["sessionID"] = ""
            serviceType["jellyfinData"] = jellyfinData
            jsonDict["serviceType"] = serviceType
        }

        if let sanitizedData = try? JSONSerialization.data(withJSONObject: jsonDict),
           let sanitizedString = String(data: sanitizedData, encoding: .utf8) {
            self.basicStorage.setString(.user, id: user.id, value: sanitizedString)
        }
    }
    
    public func getUser(userID: String) -> User? {
        guard let jsonString = self.basicStorage.getString(.user, id: userID),
              let data = jsonString.data(using: .utf8) else { return nil }

        // Try to inject tokens from Keychain
        if let tokens = KeychainTokenStorage.getTokens(forUserID: userID),
           var jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var serviceType = jsonDict["serviceType"] as? [String: Any],
           var jellyfinData = serviceType["jellyfinData"] as? [String: Any] {
            jellyfinData["accessToken"] = tokens.accessToken
            jellyfinData["sessionID"] = tokens.sessionID
            serviceType["jellyfinData"] = jellyfinData
            jsonDict["serviceType"] = serviceType

            if let enrichedData = try? JSONSerialization.data(withJSONObject: jsonDict) {
                return try? JSONDecoder().decode(User.self, from: enrichedData)
            }
        }

        // Fallback: decode as-is (migration from old storage where tokens are still in UserDefaults)
        guard let user = try? JSONDecoder().decode(User.self, from: data) else { return nil }

        // Migrate tokens to Keychain and strip from UserDefaults
        switch user.serviceType {
        case .Jellyfin(let jellyfin):
            if !jellyfin.accessToken.isEmpty {
                KeychainTokenStorage.storeTokens(
                    accessToken: jellyfin.accessToken,
                    sessionID: jellyfin.sessionID,
                    forUserID: userID
                )
                // Re-save to strip tokens from UserDefaults
                self.setUser(user: user)
            }
        }

        return user
    }
    
    public func deleteUser(userID: String) {
        KeychainTokenStorage.deleteTokens(forUserID: userID)
        self.basicStorage.deleteString(.user, id: userID)
    }
}
