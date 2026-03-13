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
    /// Type for when Stingray will ask the user about switching profiles.
    public enum ProfileSwitching: Codable, CaseIterable {
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
    
    /// Describes how and when the current user will be switched. Updating this value updates permanent storage.
    var profileSwitchingMethod: ProfileSwitching {
        willSet(newValue) {
            self.storage.setProfileSwitchingMethod(to: newValue)
            if self.profileSwitchingMethod == .manual {
                guard let newUserID = UserModel.shared.getActiveUser()?.id
                else { return }
                UserModel.shared.setActiveUser(userID: newUserID)
            }
        }
    }
    
    /// Create a SettingsModel from some kind of storage
    /// - Parameter storage: Permanent storage method to use
    init(storage: SettingsStorageProtocol = SettingStorage(basicStorage: DefaultsBasicStorage())) {
        self.storage = storage
        self.profileSwitchingMethod = storage.getProfileSwitchingMethod()
    }
}
