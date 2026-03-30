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
    /// All user setable bitrate options
    static let bitrateOptions = stride(from: 20_000_000, to: 110_000_000, by: 10_000_000).reversed() +
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
    @ObservationIgnored var storage: SettingsStorageProtocol
    
    /// Describes how and when the current user will be switched. Updating this value updates permanent storage.
    var profileSwitchingMethod: ProfileSwitching {
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
    var bitrate: Int? {
        willSet(newValue) {
            self.storage.setBitrateCap(newValue)
        }
    }

    /// Track if the user uses subtitles
    var usesSubtitles: Bool {
        get { self.userModel.activeUser?.usesSubtitles ?? false }
        set(newValue) { self.userModel.activeUser?.usesSubtitles = newValue }
    }
    
    /// Should the next piece of content load (if available)
    var autoplay: Bool {
        get { self.userModel.activeUser?.autoplay ?? false }
        set(newValue) { self.userModel.activeUser?.autoplay = newValue }
    }
    
    /// A short password required to show the users's content
    var pin: String? {
        get { self.userModel.activeUser?.pin }
        set(newValue) { self.userModel.activeUser?.pin = newValue }
    }
    
    /// Create a SettingsModel from some kind of storage
    /// - Parameters:
    ///   - userModel: Storage location of users
    ///   - storage: Settings storage location
    init(userModel: UserModel, storage: SettingsStorageProtocol) {
        self.storage = storage
        self.userModel = userModel
        self.profileSwitchingMethod = storage.getProfileSwitchingMethod()
        self.bitrate = storage.getBitrateCap()
    }
}
