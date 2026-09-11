//
//  UserModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/16/25.
//

import Foundation

/// Modifies and stores multiple users' data
public protocol UserModelProtocol: AnyObject {
    /// The signed in user
    var activeUser: (any UserProtocol)? { get set }
    /// Array of user IDs that SwiftUI will observe for changes
    var userIDs: Set<String> { get }
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

    /// Creates a user with default settings, saves it, and adds it to the known user IDs
    /// - Parameters:
    ///   - serviceURL: URL of the streaming service
    ///   - serviceType: Type of streaming service, carrying that service's credentials
    ///   - serviceID: Unique ID of the service
    ///   - id: Server-provided user ID, reused so the same account maps to the same user across sign-ins
    ///   - displayName: Name to show on screen
    /// - Returns: The stored user
    func createUser(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        displayName: String
    ) -> User
    
    /// Reset the user's settings to default
    /// - Parameter user: User to reset
    func reset(user: UserProtocol)
}

/// Basic structure for a stored user.
/// Reference semantics are required so that every holder of a user (the login state, the settings, and the user model)
/// observes the same settings rather than a private copy.
public protocol UserProtocol: AnyObject, Codable {
    /// Hands the user the storage it saves itself to whenever it changes. Pass `nil` to stop the user from saving.
    /// - Parameter storage: Storage to write changes to
    func attach(storage: UserStorageProtocol?)

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
    var usesSubtitles: Bool { get set }
    /// Quick password required for user sign-in
    var pin: String? { get set }
    /// Play the next piece of content if available
    var autoplay: Bool { get set }
    /// The user's dark theme choice
    var darkTheme: Themes { get set }
    /// The user's light theme choice
    var lightTheme: Themes { get set }
    /// How fast the viewer wants the player to run
    var playbackSpeed: PlaybackSpeed { get set }
    /// A toggle for whether to display posters
    var loadThumbnailArt: Bool { get set }
    /// A toggle for whether to display art on the detail media view
    var loadMediaBackgroundArt: Bool { get set }
    /// A toggle for whether to display media logos or text
    var replaceLogosWithText: Bool { get set }
    /// What language the user prefers to read/speak
    var preferredLangauge: Locale? { get set }
    /// Allow searching to look at episode titles to surface relevant results
    var searchEpisodeTitles: Bool { get set }
    /// Display filters options in library views
    var showFilters: Bool { get set }
    /// Display sorting options in library views
    var showSorting: Bool { get set }
    /// Display a button for refreshing a library
    var showRefreshLibrary: Bool { get set }
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
        if userID == self.activeUser?.id {
            self.activeUser?.attach(storage: nil) // A deleted user must not save itself back into storage
            self.activeUser = nil
        }
    }

    public func createUser(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        displayName: String
    ) -> User {
        // Create the user
        let user = User(
            serviceURL: serviceURL,
            serviceType: serviceType,
            serviceID: serviceID,
            id: id,
            storage: self.storage,
            displayName: displayName,
            usesSubtitles: false,
            pin: nil,
            autoplay: false,
            darkTheme: .deepSea,
            lightTheme: .beach,
            playbackSpeed: .one,
            loadThumbnailArt: true,
            loadMediaBackgroundArt: true,
            replaceLogosWithText: false,
            preferredLanguage: nil,
            searchEpisodeTitles: false,
            showFilters: true,
            showSorting: true,
            showRefreshLibrary: true
        )
        // Store the user
        self.storage.upsertUser(user: user)
        self.userIDs.insert(user.id)
        self.storage.setUserIDs(Array(self.userIDs))

        return user
    }

    public func reset(user: UserProtocol) {
        user.usesSubtitles = false
        user.pin = nil
        user.autoplay = false
        user.darkTheme = .deepSea
        user.lightTheme = .beach
        user.loadThumbnailArt = true
        user.loadMediaBackgroundArt = true
        user.replaceLogosWithText = false
        user.preferredLangauge = nil
        user.searchEpisodeTitles = false
        user.showFilters = true
        user.showSorting = true
    }
}

/// Basic structure for a user.
/// Once the user has passed through storage it saves itself on every change, so callers only ever set a property.
@Observable
public final class User: UserProtocol, Codable, Identifiable, Hashable {
    /// Storage the user writes itself back to whenever it changes. Attached by `UserStorage`, so it is never encoded.
    @ObservationIgnored private var storage: UserStorageProtocol?

    public var serviceURL: URL { didSet { self.save() } }
    public var serviceType: ServiceType { didSet { self.save() } }
    public var serviceID: String { didSet { self.save() } }
    public let id: String
    public let displayName: String

    // Settings
    public var usesSubtitles: Bool { didSet { self.save() } }
    public var pin: String? { didSet { self.save() } }
    public var autoplay: Bool { didSet { self.save() } }
    public var darkTheme: Themes { didSet { self.save() } }
    public var lightTheme: Themes { didSet { self.save() } }
    public var playbackSpeed: PlaybackSpeed { didSet { self.save() } }
    public var loadThumbnailArt: Bool { didSet { self.save() } }
    public var loadMediaBackgroundArt: Bool { didSet { self.save() } }
    public var replaceLogosWithText: Bool { didSet { self.save() } }
    public var preferredLangauge: Locale? { didSet { self.save() } }
    public var searchEpisodeTitles: Bool { didSet { self.save() } }
    public var showFilters: Bool { didSet { self.save() } }
    public var showSorting: Bool { didSet { self.save() } }
    public var showRefreshLibrary: Bool { didSet { self.save() } }

    public func attach(storage: UserStorageProtocol?) { self.storage = storage }

    /// Writes the user back to permanent storage. Called for every change, so no caller has to remember to save.
    private func save() {
        guard let storage = self.storage
        else {
            Log.warning("User \(self.id) changed before being attached to storage, so the change was not saved")
            return
        }
        storage.upsertUser(user: self)
    }

    /// Declared explicitly so that only the user's data is encoded
    private enum CodingKeys: String, CodingKey {
        case serviceURL, serviceType, serviceID, id, displayName, usesSubtitles, pin, autoplay, darkTheme, lightTheme, playbackSpeed
        case loadThumbnailArt, loadMediaBackgroundArt, replaceLogosWithText, preferredLangauge, searchEpisodeTitles, showFilters
        case showSorting, showRefreshLibrary
    }

    public static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

    /// Creates a user with every setting supplied explicitly.
    /// Call using `UserModelProtocol.createUser(...)`, which fills in Stingray's defaults and registers the user.
    /// - Parameters:
    ///   - serviceURL: URL of the streaming service
    ///   - serviceType: Type of streaming service, carrying that service's credentials
    ///   - serviceID: Unique ID of the service
    ///   - id: Server-provided user ID
    ///   - storage: Storage the user saves itself back to on every change
    ///   - displayName: Name to show on screen
    ///   - usesSubtitles: Whether the viewer wants subtitles on by default
    ///   - pin: Short password required to open this profile. `nil` for no PIN
    ///   - autoplay: Whether to roll into the next episode automatically
    ///   - darkTheme: Theme to use in system dark mode
    ///   - lightTheme: Theme to use in system light mode
    ///   - playbackSpeed: Default playback rate
    ///   - loadThumbnailArt: Whether to show poster art, or titles only
    ///   - loadMediaBackgroundArt: Whether to show backdrop art on detail views
    ///   - replaceLogosWithText: Whether to show media logos, or plain titles
    ///   - preferredLanguage: Language to render Stingray in. `nil` follows the Apple TV
    ///   - searchEpisodeTitles: Whether search should also match episode titles
    ///   - showFilters: Whether to show filter menus in library views
    ///   - showSorting: Whether to show sort menus in library views
    ///   - showRefreshLibrary: Whether to show the library refresh button
    public init(
        serviceURL: URL,
        serviceType: ServiceType,
        serviceID: String,
        id: String,
        storage: UserStorageProtocol,
        displayName: String,
        usesSubtitles: Bool,
        pin: String?,
        autoplay: Bool,
        darkTheme: Themes,
        lightTheme: Themes,
        playbackSpeed: PlaybackSpeed,
        loadThumbnailArt: Bool,
        loadMediaBackgroundArt: Bool,
        replaceLogosWithText: Bool,
        preferredLanguage: Locale?,
        searchEpisodeTitles: Bool,
        showFilters: Bool,
        showSorting: Bool,
        showRefreshLibrary: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.storage = storage
        self.serviceURL = serviceURL
        self.serviceType = serviceType
        self.serviceID = serviceID
        self.usesSubtitles = usesSubtitles
        self.pin = pin
        self.autoplay = autoplay
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
        self.showRefreshLibrary = showRefreshLibrary
    }

    /// Create a user from encoded JSON.
    /// - Parameter decoder: JSON Decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.serviceURL = try container.decode(URL.self, forKey: .serviceURL)
            self.serviceType = try container.decode(ServiceType.self, forKey: .serviceType)
            self.serviceID = try container.decode(String.self, forKey: .serviceID)
            self.id = try container.decode(String.self, forKey: .id)
            self.displayName = try container.decode(String.self, forKey: .displayName)
            // Settings
            self.pin = try container.decodeIfPresent(String.self, forKey: .pin)
            self.autoplay = (try? container.decodeIfPresent(Bool.self, forKey: .autoplay)) ?? false
            self.usesSubtitles = (try? container.decodeIfPresent(Bool.self, forKey: .usesSubtitles)) ?? false
            self.darkTheme = (try? container.decodeIfPresent(Themes.self, forKey: .darkTheme)) ?? .deepSea
            self.lightTheme = (try? container.decodeIfPresent(Themes.self, forKey: .lightTheme)) ?? .beach
            self.playbackSpeed = (try? container.decodeIfPresent(PlaybackSpeed.self, forKey: .playbackSpeed)) ?? .one
            self.loadThumbnailArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadThumbnailArt)) ?? true
            self.loadMediaBackgroundArt = (try? container.decodeIfPresent(Bool.self, forKey: .loadMediaBackgroundArt)) ?? true
            self.replaceLogosWithText = (try? container.decodeIfPresent(Bool.self, forKey: .replaceLogosWithText)) ?? false
            self.preferredLangauge = (try? container.decodeIfPresent(Locale.self, forKey: .preferredLangauge))
            self.searchEpisodeTitles = (try? container.decodeIfPresent(Bool.self, forKey: .searchEpisodeTitles)) ?? false
            self.showFilters = (try? container.decodeIfPresent(Bool.self, forKey: .showFilters)) ?? true
            self.showSorting = (try? container.decodeIfPresent(Bool.self, forKey: .showSorting)) ?? true
            self.showRefreshLibrary = (try? container.decodeIfPresent(Bool.self, forKey: .showRefreshLibrary)) ?? true
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "User") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "User") }
            else { throw JSONError.failedJSONDecode("User", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("User", error) }
    }

    /// Encode the user into JSON. Skips the storage
    /// - Parameter encoder: JSON encoder
    public func encode(to encoder: Encoder) throws(JSONError) {
        do {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(serviceURL, forKey: .serviceURL)
            try container.encode(serviceType, forKey: .serviceType)
            try container.encode(serviceID, forKey: .serviceID)
            try container.encode(id, forKey: .id)
            try container.encode(displayName, forKey: .displayName)
            // Settings
            try container.encodeIfPresent(self.pin, forKey: .pin)
            try container.encode(self.autoplay, forKey: .autoplay)
            try container.encode(self.usesSubtitles, forKey: .usesSubtitles)
            try container.encode(self.darkTheme, forKey: .darkTheme)
            try container.encode(self.lightTheme, forKey: .lightTheme)
            try container.encode(self.playbackSpeed, forKey: .playbackSpeed)
            try container.encode(self.loadThumbnailArt, forKey: .loadThumbnailArt)
            try container.encode(self.loadMediaBackgroundArt, forKey: .loadMediaBackgroundArt)
            try container.encode(self.replaceLogosWithText, forKey: .replaceLogosWithText)
            try container.encodeIfPresent(self.preferredLangauge, forKey: .preferredLangauge)
            try container.encode(self.searchEpisodeTitles, forKey: .searchEpisodeTitles)
            try container.encode(self.showFilters, forKey: .showFilters)
            try container.encode(self.showSorting, forKey: .showSorting)
            try container.encode(self.showRefreshLibrary, forKey: .showRefreshLibrary)
        }
        catch { throw JSONError.failedJSONEncode("User \(self.displayName)") }
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

    /// Rate to hand to `AVPlayer`
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

    /// User-facing multiplier label, ex. `"1.5x"`
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
    /// A Jellyfin server, carrying that user's credentials for it
    case Jellyfin(UserJellyfin)

    /// The service's name, as persisted in the encoded `type` field
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

    /// Encode the service type into JSON, tagging it so the matching case can be rebuilt.
    /// - Parameter encoder: JSON encoder
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
    /// Token authenticating this user's requests
    public let accessToken: String
    /// Server-issued session identifier, reported alongside playback progress
    public let sessionID: String
}
