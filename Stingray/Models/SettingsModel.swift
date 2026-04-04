//
//  SettingsModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/9/26.
//

import Foundation

/// Settings both for the user and globally
@Observable
public final class SettingsModel {
    /// Storage location for user details
    private let userModel: UserModel
    /// Storage location for the user's theme
    private let theme: ThemeModel
    /// All user setable bitrate options
    public static let bitrateOptions = stride(from: 20_000_000, to: 110_000_000, by: 10_000_000).reversed() +
    [15_000_000, 10_000_000, 5_000_000, 1_500_000, 500_000, 100_000]
    
    /// Type for when Stingray will ask the user about switching profiles.
    public enum ProfileSwitching: Codable, CaseIterable {
        /// When Stingray becomes active, ask the user
        case askOnResume
        /// When Stingray first launches, ask the user - typical of most streaming services
        case askOnLaunch
        /// When Stingray launches, assume the last used profile - Stingray's behavior through v1.1.0
        case manual
        /// When Stingray launches, map the current tvOS user to a Jellyfin account.
        /// If an account isn't yet mapped, ask the user.
        case syncWithTVOS
    }
    
    /// Storage device to permanently store user data
    @ObservationIgnored public var storage: SettingsStorageProtocol
    
    /// Describes how and when the current user will be switched. Updating this value updates permanent storage.
    public var profileSwitchingMethod: ProfileSwitching {
        willSet(newValue) {
            self.storage.setProfileSwitchingMethod(to: newValue)
            if self.profileSwitchingMethod == .manual {
                guard let newUser = self.userModel.activeUser
                else { return }
                self.userModel.activeUser = newUser
            }
        }
    }
    
    /// Video bitrate option
    public var bitrate: Int? {
        willSet(newValue) {
            self.storage.setBitrateCap(newValue)
        }
    }

    /// Track if the user uses subtitles
    public var usesSubtitles: Bool {
        get { self.userModel.activeUser?.usesSubtitles ?? false }
        set(newValue) { self.userModel.activeUser?.usesSubtitles = newValue }
    }
    
    /// Should the next piece of content load (if available)
    public var autoplay: Bool {
        get { self.userModel.activeUser?.autoplay ?? false }
        set(newValue) { self.userModel.activeUser?.autoplay = newValue }
    }
    
    /// How fast the player plays content
    public var playbackSpeed: PlaybackSpeed {
        get { self.userModel.activeUser?.playbackSpeed ?? .one }
        set(newValue) { self.userModel.activeUser?.playbackSpeed = newValue }
    }
    
    /// A short password required to show the users's content
    public var pin: String? {
        get { self.userModel.activeUser?.pin }
        set(newValue) { self.userModel.activeUser?.pin = newValue }
    }
    
    /// The desired dark theme for the user
    public var themeDark: ThemeModel.Themes {
        get { self.theme.dark }
        set(newValue) {
            self.theme.dark = newValue
            self.userModel.activeUser?.darkTheme = newValue
        }
    }

    /// The desired light theme for the user
    public var themeLight: ThemeModel.Themes {
        get { self.theme.light }
        set(newValue) {
            self.theme.light = newValue
            self.userModel.activeUser?.lightTheme = newValue
        }
    }
    
    /// The current theme in use
    public var themeCurrent: any ThemeProtocol { self.theme.currentTheme }
    
    /// Should the poster art be displayed
    public var loadThumbnailArt: Bool {
        get { self.userModel.activeUser?.loadThumbnailArt ?? true }
        set(newValue) { self.userModel.activeUser?.loadThumbnailArt = newValue }
    }
    
    /// Should the detail media view load background art
    public var loadMediaBackgroundArt: Bool {
        get { self.userModel.activeUser?.loadMediaBackgroundArt ?? true }
        set(newValue) { self.userModel.activeUser?.loadMediaBackgroundArt = newValue }
    }
    
    /// Allows replacing media logos with text
    public var replaceLogosWithText: Bool {
        get { self.userModel.activeUser?.replaceLogosWithText ?? false }
        set(newValue) { self.userModel.activeUser?.replaceLogosWithText = newValue }
    }
    
    /// Create a SettingsModel from some kind of storage
    /// - Parameters:
    ///   - userModel: Storage location of users
    ///   - storage: Settings storage location
    public init(userModel: UserModel, storage: SettingsStorageProtocol, theme: ThemeModel) {
        self.storage = storage
        self.userModel = userModel
        self.profileSwitchingMethod = storage.getProfileSwitchingMethod()
        self.bitrate = storage.getBitrateCap()
        self.theme = theme
    }
}
