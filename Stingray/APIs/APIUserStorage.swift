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
    public let basicStorage: BasicStorageProtocol
    public var localUserID: String
    
    public init(basicStorage: BasicStorageProtocol) {
        Log.info("Setting up Basic Storage")
        self.basicStorage = basicStorage
        self.localUserID = ""
        
        // Check if registered userIDs exist - iCloud seems to screw these up sometimes
        var userIDs = self.getUserIDs()
        userIDs = userIDs.filter { return self.getUser(userID: $0) != nil }
        self.setUserIDs(userIDs)
        
        // Ensure there's a UUID for each tvOS user
        if let localUserID = self.basicStorage.getString(.localUserID) { // Local user ID is already configured
            self.localUserID = localUserID
        }
        else { // New tvOS user. Generate a local uesr ID
            self.localUserID = UUID().uuidString
            self.basicStorage.setString(.localUserID, value: localUserID)
            self.basicStorage.setTopShelfString(.localUserID, value: localUserID)
        }
        Log.info("Local User ID: \(localUserID)")
    }
    
    public func getUserIDs() -> [String] {
        return (try? self.basicStorage.getSecureData(.userIDs)) ?? [] // TODO: Silently fails
    }
    
    public func setUserIDs(_ userIDs: [String]) {
        try? self.basicStorage.setSecureData(.userIDs, data: userIDs) // TODO: Silently fails
    }
    
    public func getActiveUserID() -> String? {
        if Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? false {
            return self.basicStorage.getTopShelfString(.defaultStreamingUserID)
        }
        let method: SettingsModel.ProfileSwitching = (try? self.basicStorage.getSecureData(.userSwitchingMethod)) ?? .askOnLaunch
        switch method {
        case .manual:
            let userID: String? = try? self.basicStorage.getSecureData(.defaultStreamingUserID) ?? nil // Fallback to ask
            self.basicStorage.setString(.linkUser(localUserID), value: userID ?? "")
            self.basicStorage.setTopShelfString(.defaultStreamingUserID, value: userID ?? "")
            return userID
        case /*.syncWithTVOS,*/ .askOnLaunch, .askOnResume:
            if Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? false { // Top shelf reads from a different storage
                return self.basicStorage.getTopShelfString(.defaultStreamingUserID)
            }
            return try? self.basicStorage.getSecureData(.linkUser(localUserID))
        }
    }
    
    public func setActiveUserID(id serverUserID: String) {
        self.basicStorage.setTopShelfString(.defaultStreamingUserID, value: serverUserID) // Set Top Shelf user ID
        try? self.basicStorage.setSecureData(.defaultStreamingUserID, data: serverUserID) // TODO: Silently fails
        try? self.basicStorage.setSecureData(.linkUser(localUserID), data: serverUserID) // TODO: Silently fails
        Log.info("Linking tvOS \(localUserID) -> Jellyfin \(serverUserID)")
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
