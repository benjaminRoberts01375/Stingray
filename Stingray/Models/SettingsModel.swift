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
    /// Shared instance to avoid repeated instantiation
    static let shared = SettingsModel()
    
    /// Type for when Stingray will ask the user about switching profiles.
    public enum ProfileSwitching: Codable {
        /// When Stingray launches, ask the user - typical of most streaming services
        case askOnLaunch
        /// When Stingray launches, assume the last used profile - Stingray's behavior through v1.1.0
        case manual
        /// When Stingray launches, map the current tvOS user to a Jellyfin account.
        /// If an account isn't yet mapped, ask the user.
        case syncWithTVOS
    }
    
    /// Storage device to permanently store user data
    @ObservationIgnored var storage: SettingsStorageProtocol
    /// Describes how and when the current user will be switched
    var profileSwitchingMethod: ProfileSwitching
    
    /// Create a SettingsModel from some kind of storage
    /// - Parameter storage: Permanent storage method to use
    private init(storage: SettingsStorageProtocol = SettingStorage(basicStorage: DefaultsBasicStorage())) {
        self.storage = storage
        self.profileSwitchingMethod = .manual
        self.profileSwitchingMethod = self.storage.getProfileSwitchingMethod()
    }
}
