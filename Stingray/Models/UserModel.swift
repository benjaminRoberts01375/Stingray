//
//  User.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

/// Modifies and stores multiple users' data
public protocol UserModelProtocol {
    /// The signed in user
    var activeUser: (any UserProtocol)? { get set }
    /// Array of user IDs that SwiftUI will observe for changes
    var userIDs: Set<String> { get }

    /// Adds a user to storage based on a `User` type.
    /// - Parameter user: User to add or update
    func addUser(_ user: any UserProtocol)
    /// Gets all users
    /// - Returns: All available users
    func getUsers() -> [User]
    /// Get a single user from storage
    /// - Parameter id: ID of the user to get
    /// - Returns: The user if found
    func getUser(id: String) -> User?
    /// Deletes a user based on their ID
    /// - Parameter userID: ID of the user to delete
    func deleteUser(_ userID: String)
}

/// Basic structure for a stored user
public protocol UserProtocol: Codable {
    /// URL to the streaming service
    var serviceURL: URL { get }
    /// Type of streaming service
    var serviceType: ServiceType { get }
    /// Unique ID for the service
    var serviceID: String { get }
    /// Unique user ID
    var id: String { get }
    /// Name of the user to show on screen
    var displayName: String { get }

    // Settings
    /// Track if the user wants subtitles
    var usesSubtitles: Bool { get set}
    /// Quick password required for user sign-in
    var pin: String? { get set}
    /// Play the next piece of content if available
    var autoplay: Bool { get set}
    /// The user's dark theme choice
    var darkTheme: Themes { get set}
    /// The user's light theme choice
    var lightTheme: Themes { get set}
    /// How fast the viewer wants the player to run
    var playbackSpeed: PlaybackSpeed { get set}
    /// A toggle for whether to display posters
    var loadThumbnailArt: Bool { get set}
    /// A toggle for whether to display art on the detail media view
    var loadMediaBackgroundArt: Bool { get set}
    /// A toggle for whether to display media logos or text
    var replaceLogosWithText: Bool { get set}
    /// What language the user prefers to read/speak
    var preferredLangauge: Locale? { get set}
    /// Allow searching to look at episode titles to surface relevant results
    var searchEpisodeTitles: Bool { get set }
    /// Display filters options in library views
    var showFilters: Bool { get set }
    /// Display sorting options in library views
    var showSorting: Bool { get set }
}

/// Basic data to store about the user
@Observable
public final class UserModel: UserModelProtocol {
    /// Storage device to permanently store user data
    private var storage: UserStorageProtocol

    public var activeUser: (any UserProtocol)? {
        didSet {
            guard let userID = self.activeUser?.id else { return }
            self.storage.setActiveUserID(id: userID)
            guard let user = self.activeUser else { return }
            self.storage.upsertUser(user: user)
        }
    }

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

    public func addUser(_ user: any UserProtocol) {
        self.storage.upsertUser(user: user)
        self.userIDs.insert(user.id)
        self.storage.setUserIDs(Array(self.userIDs))
    }

    public func getUsers() -> [User] {
        return self.userIDs.compactMap { self.storage.getUser(userID: $0) }
    }

    public func getUser(id: String) -> User? {
        return self.storage.getUser(userID: id)
    }

    public func deleteUser(_ userID: String) {
        userIDs.remove(userID)
        storage.setUserIDs(Array(userIDs))
        storage.deleteUser(userID: userID)
        if userID == self.activeUser?.id { self.activeUser = nil }
    }
}

/// Basic structure for a user
public struct User: UserProtocol, Codable, Identifiable, Hashable {
    public let serviceURL: URL
    public var serviceType: ServiceType
    public let serviceID: String
    public let id: String
    public let displayName: String

    // Settings
    public var usesSubtitles: Bool
    public var pin: String?
    public var autoplay: Bool
    public var darkTheme: Themes
    public var lightTheme: Themes
    public var playbackSpeed: PlaybackSpeed
    public var loadThumbnailArt: Bool
    public var loadMediaBackgroundArt: Bool
    public var replaceLogosWithText: Bool
    public var preferredLangauge: Locale?
    public var searchEpisodeTitles: Bool
    public var showFilters: Bool
    public var showSorting: Bool

    public init(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        displayName: String,
        usesSubtitles: Bool = false,
        pin: String? = nil,
        autplay: Bool = false,
        darkTheme: Themes = .deepSea,
        lightTheme: Themes = .beach,
        playbackSpeed: PlaybackSpeed = .one,
        loadThumbnailArt: Bool = true,
        loadMediaBackgroundArt: Bool = true,
        replaceLogosWithText: Bool = false,
        preferredLanguage: Locale? = nil,
        searchEpisodeTitles: Bool = false,
        showFilters: Bool = true,
        showSorting: Bool = true
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
        self.replaceLogosWithText = replaceLogosWithText
        self.preferredLangauge = preferredLanguage
        self.searchEpisodeTitles = searchEpisodeTitles
        self.showFilters = showFilters
        self.showSorting = showSorting
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
            darkTheme = (try? container.decodeIfPresent(Themes.self, forKey: .darkTheme)) ?? .deepSea
            lightTheme = (try? container.decodeIfPresent(Themes.self, forKey: .lightTheme)) ?? .beach
            playbackSpeed = (try? container.decodeIfPresent(PlaybackSpeed.self, forKey: .playbackSpeed)) ?? .one
            loadThumbnailArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadThumbnailArt)) ?? true
            loadMediaBackgroundArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadMediaBackgroundArt)) ?? true
            replaceLogosWithText = (try? container.decodeIfPresent(Bool.self, forKey: .replaceLogosWithText)) ?? false
            preferredLangauge = (try? container.decodeIfPresent(Locale.self, forKey: .preferredLangauge))
            searchEpisodeTitles = (try? container.decodeIfPresent(Bool.self, forKey: .searchEpisodeTitles)) ?? false
            showFilters = (try? container.decodeIfPresent(Bool.self, forKey: .showFilters)) ?? true
            showSorting = (try? container.decodeIfPresent(Bool.self, forKey: .showSorting)) ?? true
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

/// Jellyfin-specific userdata
public struct UserJellyfin: Codable, Hashable {
    public let accessToken: String
    public let sessionID: String
}
