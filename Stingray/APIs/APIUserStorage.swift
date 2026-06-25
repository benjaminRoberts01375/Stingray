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
    func upsertUser(user: any UserProtocol)
    /// Get a `User` from storage
    /// - Parameter userID: ID of the user to find
    /// - Returns: The formatted `User`
    func getUser(userID: String) -> User?
    /// Deletes only user data
    /// - Parameter userID: ID of the user to remove
    func deleteUser(userID: String)
}

public final class UserStorage: UserStorageProtocol {
    public let basicStorage: BasicStorageProtocol
    
    public init(basicStorage: BasicStorageProtocol) { self.basicStorage = basicStorage }
    
    public func getUserIDs() -> [String] {
        return self.basicStorage.getStringArray(.userIDs) ?? []
    }
    
    public func setUserIDs(_ userIDs: [String]) {
        self.basicStorage.setStringArray(.userIDs, value: userIDs)
    }
    
    public func getActiveUserID() -> String? {
        return self.basicStorage.getString(.defaultStreamingUserID)
    }
    
    public func setActiveUserID(id serverUserID: String) {
        self.basicStorage.setString(.defaultStreamingUserID, value: serverUserID) // Set Top Shelf user ID
    }
    
    public func upsertUser(user: any UserProtocol) {
        self.basicStorage.setObject(.user(user.id), value: user)
    }
    
    public func getUser(userID: String) -> User? {
        return self.basicStorage.getObject(.user(userID))
    }
    
    public func deleteUser(userID: String) {
        self.basicStorage.delete(.user(userID))
    }
}
