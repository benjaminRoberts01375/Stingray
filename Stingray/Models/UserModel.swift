//
//  User.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

/// Basic data to store about the user
@Observable
final class UserModel {
    /// Storage device to permanently store user data
    var storage: UserStorageProtocol
    
    /// The signed in user
    public var activeUser: User? {
        willSet(newUser) {
            guard let userID = newUser?.id else { return }
            self.storage.setActiveUserID(id: userID)
        }
    }
    
    /// Array of user IDs that SwiftUI will observe for changes
    public private(set) var userIDs: Set<String> = []
    
    /// Create the model based on a storage medium
    /// - Parameter storage: The storage medium
    init(storage: UserStorageProtocol) {
        self.storage = storage
        self.userIDs = Set(self.storage.getUserIDs())
        self.activeUser = self.getActiveUser()
    }
    
    /// Adds a user to storage based on a `User` type
    /// - Parameter user: User to add
    func addUser(_ user: User) {
        userIDs.insert(user.id)
        storage.upsertUser(user: user)
        storage.setUserIDs(Array(userIDs))
    }
    
    /// Gets the most recent Jellyfin user's ID. `nil` implies no most recently user, but there may be available users.
    /// - Returns: The most recent user
    private func getActiveUser() -> User? {
        guard let userID = self.storage.getActiveUserID() else { return nil }
        return self.storage.getUser(userID: userID)
    }
    
    /// Gets all users
    func getUsers() -> [User] {
        return self.userIDs.compactMap { self.storage.getUser(userID: $0) }
    }
    
    /// Updates a user's stored data
    /// - Parameter user: Updated `User`
    func updateUser(_ user: User) {
        if !userIDs.contains(user.id) {
            self.addUser(user)
        } else {
            self.storage.upsertUser(user: user)
        }
    }
    
    /// Deletes a user based on their ID
    /// - Parameter userID: ID of the user to delete
    func deleteUser(_ userID: String) {
        userIDs.remove(userID)
        storage.setUserIDs(Array(userIDs))
        storage.deleteUser(userID: userID)
    }
}

/// Jellyfin-specific userdata
public struct UserJellyfin: Codable {
    let accessToken: String
    let sessionID: String
}

/// Types of streaming services
/// Temporary name for compatibility until migration is complete
public enum ServiceType: Codable {
    case Jellyfin(UserJellyfin)
    
    public var rawValue: String {
        switch self {
        case .Jellyfin:
            return "Jellyfin"
        }
    }
    
    // Custom Codable implementation for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, jellyfinData
    }
    
    public func encode(to encoder: Encoder) throws(JSONError) {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .Jellyfin(let data):
            do {
                try container.encode("Jellyfin", forKey: .type)
                try container.encode(data, forKey: .jellyfinData)
            } catch {
                throw JSONError.failedJSONEncode("Service Type")
            }
        }
    }
    
    /// Create a service type from JSON.
    /// - Parameter decoder: JSON decoder.
    /// - Throws `JSONErrors` if the type is unknown.
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "Jellyfin":
                let data = try container.decode(UserJellyfin.self, forKey: .jellyfinData)
                self = .Jellyfin(data)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown service type: \(type)"
                )
            }
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "ServiceType") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "ServiceType") }
            else { throw JSONError.failedJSONDecode("ServiceType", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("ServiceType", error) }
    }
}

/// Basic structure for a user
public struct User: Codable, Identifiable {
    let serviceURL: URL
    let serviceType: ServiceType
    let serviceID: String
    public let id: String
    let displayName: String
    var usesSubtitles: Bool // Set default as false
    
    init(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        displayName: String,
        usesSubtitles: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.serviceURL = serviceURL
        self.serviceType = serviceType
        self.serviceID = serviceID
        self.usesSubtitles = usesSubtitles
    }
    
    /// Create a user from encoded JSON.
    /// - Parameter decoder: JSON Decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            serviceURL = try container.decode(URL.self, forKey: .serviceURL)
            serviceType = try container.decode(ServiceType.self, forKey: .serviceType)
            serviceID = try container.decode(String.self, forKey: .serviceID)
            id = try container.decode(String.self, forKey: .id)
            displayName = try container.decode(String.self, forKey: .displayName)
            
            usesSubtitles = try container.decodeIfPresent(Bool.self, forKey: .usesSubtitles) ?? false
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "User") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "User") }
            else { throw JSONError.failedJSONDecode("User", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("User", error) }
    }
}
