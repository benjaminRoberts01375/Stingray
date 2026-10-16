//
//  StorageKeys.swift
//  Stingray
//
//  Created by Ben Roberts on 10/16/26.
//

import Foundation

// Where and under which names Stingray keeps its data. Shared with extensions (ex. TopShelf) so they read exactly what the app writes,
// without depending on the app's models.

/// Available keys for interacting with the permanent storage.
public enum StorageKeys: RawRepresentable {
    /// Active user
    case defaultStreamingUserID
    /// Key for all available userIDs
    case userIDs
    /// The user and userID to modify
    case user(String)
    /// A setting for how/when users should be switched
    case userSwitchingMethod
    /// A unique ID for the maximum bitrate option
    case maxBitrate

    /// App group whose defaults are shared between Stingray and its extensions
    public static let appGroup = "group.com.benlab.stingray"

    /// A string representation of the enum
    public var rawValue: String {
        switch self {
        case .defaultStreamingUserID: return "defaultStreamingUserID"
        case .userIDs: return "userIDs"
        case .user(let id): return "user\(id)"
        case .userSwitchingMethod: return "userSwitchingMethod"
        case .maxBitrate: return "maxBitrate"
        }
    }

    /// Rebuilds a key from the string it was stored under.
    /// iCloud change notifications report raw key names, so they have to be mapped back to cases before use.
    /// - Parameter rawValue: The stored string form of a key
    /// - Returns: The matching key, or `nil` when the string isn't one Stingray owns
    public init?(rawValue: String) {
        switch rawValue {
        // Exact cases are matched first, since `userIDs` and `userSwitchingMethod` would otherwise parse as user IDs
        case StorageKeys.defaultStreamingUserID.rawValue: self = .defaultStreamingUserID
        case StorageKeys.userIDs.rawValue: self = .userIDs
        case StorageKeys.userSwitchingMethod.rawValue: self = .userSwitchingMethod
        case StorageKeys.maxBitrate.rawValue: self = .maxBitrate
        default:
            guard rawValue.hasPrefix("user") else { return nil }
            self = .user(String(rawValue.dropFirst("user".count)))
        }
    }
}

// MARK: Stored User JSON
/// JSON keys of a stored `User`.
public enum StoredUserKeys: String, CodingKey {
    case serviceURL, serviceType, serviceID, id, displayName, usesSubtitles, pin, autoplay, darkTheme, lightTheme, playbackSpeed
    case loadThumbnailArt, loadMediaBackgroundArt, replaceLogosWithText, preferredLangauge, searchEpisodeTitles, showFilters
    case showSorting, showRefreshLibrary
}

/// JSON keys of a stored `ServiceType`, which tags which service a user belongs to.
public enum StoredServiceTypeKeys: String, CodingKey {
    case type
    case jellyfinData
}

/// JSON keys of a stored `UserJellyfin`.
public enum StoredJellyfinKeys: String, CodingKey {
    case accessToken
    case sessionID
}
