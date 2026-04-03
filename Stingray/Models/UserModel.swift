//
//  User.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

/// Basic data to store about the user
@Observable
public final class UserModel {
    /// Storage device to permanently store user data
    public var storage: UserStorageProtocol
    
    /// The signed in user
    public var activeUser: User? {
        didSet {
            guard let userID = self.activeUser?.id else { return }
            self.storage.setActiveUserID(id: userID)
            guard let user = self.activeUser else { return }
            self.storage.upsertUser(user: user)
        }
    }
    
    /// Array of user IDs that SwiftUI will observe for changes
    public private(set) var userIDs: Set<String> = []
    
    /// Create the model based on a storage medium
    /// - Parameter storage: The storage medium
    public init(storage: UserStorageProtocol) {
        self.storage = storage
        self.userIDs = Set(self.storage.getUserIDs())
        self.activeUser = nil
        
        guard let userID = self.storage.getActiveUserID() else { return }
        self.activeUser = self.storage.getUser(userID: userID)
    }
    
    /// Adds a user to storage based on a `User` type
    /// - Parameter user: User to add
    public func addUser(_ user: User) {
        userIDs.insert(user.id)
        storage.upsertUser(user: user)
        storage.setUserIDs(Array(userIDs))
    }
    
    /// Gets all users
    public func getUsers() -> [User] {
        return self.userIDs.compactMap { self.storage.getUser(userID: $0) }
    }
    
    /// Deletes a user based on their ID
    /// - Parameter userID: ID of the user to delete
    public func deleteUser(_ userID: String) {
        userIDs.remove(userID)
        storage.setUserIDs(Array(userIDs))
        storage.deleteUser(userID: userID)
        if userID == self.activeUser?.id { self.activeUser = nil }
    }
}

/// Jellyfin-specific userdata
public struct UserJellyfin: Codable, Hashable {
    public let accessToken: String
    public let sessionID: String
}

/// Types of streaming services
/// Temporary name for compatibility until migration is complete
public enum ServiceType: Codable, Hashable {
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
public struct User: Codable, Identifiable, Hashable {
    public let serviceURL: URL
    public let serviceType: ServiceType
    public let serviceID: String
    public let id: String
    public let displayName: String
    
    // Settings
    /// Track if the user wants subtitles
    public var usesSubtitles: Bool
    /// Quick password required for user sign-in
    public var pin: String?
    /// Play the next piece of content if available
    public var autoplay: Bool
    /// The user's dark theme choice
    public var darkTheme: ThemeModel.Themes
    /// The user's light theme choice
    public  var lightTheme: ThemeModel.Themes
    /// How fast the viewer wants the player to run
    public var playbackSpeed: PlaybackSpeed
    /// A toggle for whether to display posters
    public var loadThumbnailArt: Bool
    /// A toggle for whether to display art on the detail media view
    public var loadMediaBackgroundArt: Bool
    
    public init(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        displayName: String,
        usesSubtitles: Bool = false,
        pin: String? = nil,
        autplay: Bool = false,
        darkTheme: ThemeModel.Themes = .deepSea,
        lightTheme: ThemeModel.Themes = .notesApp,
        playbackSpeed: PlaybackSpeed = .one,
        loadThumbnailArt: Bool = true,
        loadMediaBackgroundArt: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.serviceURL = serviceURL
        self.serviceType = serviceType
        self.serviceID = serviceID
        self.usesSubtitles = usesSubtitles
        self.pin = pin
        self.autoplay = autplay
        self.darkTheme = darkTheme
        self.lightTheme = lightTheme
        self.playbackSpeed = playbackSpeed
        self.loadThumbnailArt = loadThumbnailArt
        self.loadMediaBackgroundArt = loadMediaBackgroundArt
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
            // Settings
            pin = try container.decodeIfPresent(String.self, forKey: .pin)
            autoplay = (try? container.decodeIfPresent(Bool.self, forKey: .autoplay)) ?? false
            usesSubtitles = (try? container.decodeIfPresent(Bool.self, forKey: .usesSubtitles)) ?? false
            darkTheme = (try? container.decodeIfPresent(ThemeModel.Themes.self, forKey: .darkTheme)) ?? .deepSea
            lightTheme = (try? container.decodeIfPresent(ThemeModel.Themes.self, forKey: .lightTheme)) ?? .beach
            playbackSpeed = (try? container.decodeIfPresent(PlaybackSpeed.self, forKey: .playbackSpeed)) ?? .one
            loadThumbnailArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadThumbnailArt)) ?? true
            loadMediaBackgroundArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadMediaBackgroundArt)) ?? true
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "User") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "User") }
            else { throw JSONError.failedJSONDecode("User", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("User", error) }
    }
}

// This should go in PlayerViewModel.swift, but can't because of the TopShelf
/// How fast the player can play content back.
public enum PlaybackSpeed: CaseIterable, Codable {
    /// 1/4 the speed of realtime
    case quarter
    /// 1/2 the speed of realtime
    case half
    /// Realtime
    case one
    /// 1.25x the speed of realtime
    case oneAndQuarter
    /// 1.5x the speed of realtime
    case oneAndHalf
    /// 2x the speed of realtime
    case two
    
    public var value: Float {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .one: return 1
        case .oneAndQuarter: return 1.25
        case .oneAndHalf: return 1.5
        case .two: return 2
        }
    }
    
    public var name: String {
        switch self {
        case .quarter: return "0.25x"
        case .half: return "0.5x"
        case .one: return "1x"
        case .oneAndQuarter: return "1.25x"
        case .oneAndHalf: return "1.5x"
        case .two: return "2x"
        }
    }
}
