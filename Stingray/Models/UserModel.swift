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
        storage.setUserIDs(userIDs)
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
    
    func updateUser(_ user: User) {
        let userIDs = storage.getUserIDs()
        if !userIDs.contains(user.id) {
            self.addUser(user)
        } else {
            self.storage.setUser(user: user)
        }
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
public struct User: Codable, Identifiable {
    let serviceURL: URL
    let serviceType: ServiceType
    let serviceID: String
    public let id: String
    let displayName: String
    var usesSubtitles: Bool // Set default as false
    var bitrate: Int?
    
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
    
    // Custom decoder to provide default value for usesSubtitles
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Required for all users
        serviceURL = try container.decode(URL.self, forKey: .serviceURL)
        serviceType = try container.decode(ServiceType.self, forKey: .serviceType)
        serviceID = try container.decode(String.self, forKey: .serviceID)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        
        // User settings that may not have been configured yet
        usesSubtitles = try container.decodeIfPresent(Bool.self, forKey: .usesSubtitles) ?? false
        bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate)
    }
}
