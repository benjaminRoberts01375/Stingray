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
    /// Get the most recently used streaming user ID
    /// - Returns: The user ID
    func getDefaultStreamingUserID() -> String?
    /// Set the default user to use on startup
    /// - Parameter id: The default user ID
    func setDefaultStreamingUserID(id: String)
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
        return (try? self.basicStorage.getSecureData(.userIDs)) ?? [] // TODO: Silently fails
    }
    
    public func setUserIDs(_ userIDs: [String]) {
        try? self.basicStorage.setSecureData(.userIDs, data: userIDs) // TODO: Silently fails
    }
    
    public func getDefaultStreamingUserID() -> String? {
        self.basicStorage.getString(.defaultStreamingUserID, id: "")
    }
    
    public func setDefaultStreamingUserID(id: String) {
        self.basicStorage.setString(.defaultStreamingUserID, id: "", value: id)
    }
    
    public func setUser(user: User) {
        if let encoded = try? JSONEncoder().encode(user),
           let jsonString = String(data: encoded, encoding: .utf8) {
            self.basicStorage.setString(.user, id: user.id, value: jsonString)
        }
    }
    
    public func getUser(userID: String) -> User? {
        guard let jsonString = self.basicStorage.getString(.user, id: userID),
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    public func deleteUser(userID: String) {
        self.basicStorage.deleteString(.user, id: userID)
    }
}
