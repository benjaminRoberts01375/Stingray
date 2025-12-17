//
//  User.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

final class UserModel {
    var storage: UserStorageProtocol
    
    init(storage: UserStorageProtocol = UserStorage(basicStorage: DefaultsBasicStorage())) {
        self.storage = storage
    }
    
    func addUser(_ user: User) {
        var userIDs = storage.getUserIDs()
        userIDs.append(user.id)
        storage.setUser(user: user)
    }
    
    func getDefaultUser() -> User? {
        guard let defaultID = self.storage.getDefaultUserID() else { return nil }
        return self.storage.getUser(userID: defaultID)
    }
    
    func setDefaultUser(userID: String) {
        self.storage.setDefaultUserID(id: userID)
    }
    
    func getUsers() -> [User] {
        return self.storage.getUserIDs().compactMap { self.storage.getUser(userID: $0) }
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .Jellyfin(let data):
            try container.encode("Jellyfin", forKey: .type)
            try container.encode(data, forKey: .jellyfinData)
        }
    }
    
    public init(from decoder: Decoder) throws {
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
}

/// Basic structure for a user
public struct User: Codable {
    let serviceURL: URL
    let serviceType: ServiceType
    let serviceID: String
    let id: String
    let displayName: String
}
