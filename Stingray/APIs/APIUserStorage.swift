//
//  APIUserStorage.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

/// Local storage for modifying user-related data
public protocol UserStorageProtocol {
    /// Get all user IDs for all streaming services
    func getUserIDs() -> [String]
    /// Set all user IDs to an array of IDs
    /// - Parameter userIDs: User IDs to set
    func setUserIDs(_ userIDs: [String])
    /// Gets the most recent Jellyfin user's ID. `nil` implies no most recently user, but there may be available users.
    /// - Returns: The user ID
    func getActiveUserID() -> String?
    /// Set the current user to use on startup
    /// - Parameter id: The current user ID
    func setActiveUserID(id: String)
    /// Save a `User` into storage
    /// - Parameters:
    ///   - user: User to save
    func upsertUser(user: User)
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
        return (try? self.basicStorage.getSecureData(.userIDs)) ?? [] // TODO: Silently fails
    }
    
    public func setUserIDs(_ userIDs: [String]) {
        try? self.basicStorage.setSecureData(.userIDs, data: userIDs) // TODO: Silently fails
    }
    
    public func getActiveUserID() -> String? {
        let method: SettingsModel.ProfileSwitching = (try? self.basicStorage.getSecureData(.userSwitchingMethod)) ?? .askOnLaunch
        switch method {
        case .manual:
            let userID: String? = try? self.basicStorage.getSecureData(.defaultStreamingUserID) ?? nil // Fallback to ask
            self.basicStorage.setString(.defaultStreamingUserID, value: userID ?? "")
            self.basicStorage.setTopShelfString(.defaultStreamingUserID, value: userID ?? "")
            return userID
        case .syncWithTVOS, .askOnLaunch:
            if Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? false { // Top shelf reads from a different storage
                return self.basicStorage.getTopShelfString(.defaultStreamingUserID)
            }
            return self.basicStorage.getString(.defaultStreamingUserID)
        }
    }
    
    public func setActiveUserID(id: String) {
        self.basicStorage.setString(.defaultStreamingUserID, value: id) // Set per-user active ID
        self.basicStorage.setTopShelfString(.defaultStreamingUserID, value: id) // Set Top Shelf user ID
        try? self.basicStorage.setSecureData(.defaultStreamingUserID, data: id) // TODO: Silently fails
    }
    
    public func upsertUser(user: User) {
        try? self.basicStorage.setSecureData(.user(user.id), data: user)
    }
    
    public func getUser(userID: String) -> User? {
        return try? self.basicStorage.getSecureData(.user(userID))
    }
    
    public func deleteUser(userID: String) {
        self.basicStorage.deleteString(.user(userID))
    }
}
