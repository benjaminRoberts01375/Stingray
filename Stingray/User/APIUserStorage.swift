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
    /// Save a `User` into storage
    /// - Parameters:
    ///   - user: User to save
    func setUser(user: User)
    /// Get a `User` from storage
    /// - Parameter userID: ID of the user to find
    /// - Returns: The formatted `User`
    func getUser(userID: String) throws -> User?
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
    
    public func setUser(user: User) {
        if let encoded = try? JSONEncoder().encode(user),
           let jsonString = String(data: encoded, encoding: .utf8) {
            self.basicStorage.setString(.user, id: user.id, value: jsonString)
        }
    }
    
    public func getUser(userID: String) throws -> User? {
        guard let jsonString = self.basicStorage.getString(.user, id: userID),
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
}
