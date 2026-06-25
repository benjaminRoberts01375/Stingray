//
//  SettingsModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/9/26.
//

import SwiftUI

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
    public enum ProfileSwitching: CaseIterable, RawRepresentable {
        public init?(rawValue: String) {
            if rawValue == ProfileSwitching.askOnLaunch.rawValue { self = .askOnLaunch }
            else if rawValue == ProfileSwitching.askOnResume.rawValue { self = .askOnResume }
            else { self = .manual }
        }
        
        public var rawValue: String {
            switch self {
            case .askOnResume: return "askOnResume"
            case .askOnLaunch: return "askOnLaunch"
            case .manual: return "manual"
            }
        }
        
        /// When Stingray becomes active, ask the user
        case askOnResume
        /// When Stingray first launches, ask the user - typical of most streaming services
        case askOnLaunch
        /// When Stingray launches, assume the last used profile - Stingray's behavior through v1.1.0
        case manual
        
        /// Picker display name
        public var displayName: LocalizedStringKey {
            switch self {
            case .askOnLaunch:
                return "Ask on Launch"
            case .manual:
                return "Manual"
            case .askOnResume:
                return "Ask on Resume"
            }
        }
        
        /// More thorough description of the selected values.
        public var description: LocalizedStringKey {
            switch self {
            case .askOnResume:
                return """
                You'll be prompted for your choice of account when Jellyfin launches or opens from the background. \
                This can be annoying to some and triggers on things like Control Center. \
                If only one user is signed in, the user picker screen will be skipped.
                """
            case .askOnLaunch:
                return """
                You'll be prompted for your choice of account on each launch. Typical of most streaming services.
                If only one user is signed in, the user picker screen will be skipped.
                """
            case .manual:
                return "Whoever was last signed in will remain signed in."
            }
        }
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
    public var themeDark: Themes {
        get { self.theme.dark }
        set(newValue) {
            self.theme.dark = newValue
            self.userModel.activeUser?.darkTheme = newValue
        }
    }

    /// The desired light theme for the user
    public var themeLight: Themes {
        get { self.theme.light }
        set(newValue) {
            self.theme.light = newValue
            self.userModel.activeUser?.lightTheme = newValue
        }
    }
    
    /// The system color theme (ex. dark mode vs light mode)
    public var systemTheme: ColorScheme {
        get { self.theme.systemColorScheme }
        set(newValue) {self.theme.systemColorScheme = newValue}
    }
    
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
    
    /// The language the user wants Stingray to render with
    public var langauge: Locale? {
        get { self.userModel.activeUser?.preferredLangauge }
        set(newValue) { self.userModel.activeUser?.preferredLangauge = newValue }
    }
    
    /// Create a SettingsModel from some kind of storage
    /// - Parameters:
    ///   - userModel: Storage location of users
    ///   - storage: Settings storage location
    ///   - theme: Theme storage location
    public init(userModel: UserModel, storage: SettingsStorageProtocol, theme: ThemeModel) {
        self.storage = storage
        self.userModel = userModel
        self.profileSwitchingMethod = storage.getProfileSwitchingMethod()
        self.bitrate = storage.getBitrateCap()
        self.theme = theme
    }
}
