//
//  APISettingsStorage.swift
//  Stingray
//
//  Created by Ben Roberts on 3/9/26.
//

import Foundation

/// Defines methods for setting and getting settings from permanent storage
public protocol SettingsStorageProtocol {
    /// Sets the profile switching in permanent storage.
    /// - Parameter method: Profile switch method to store.
    func setProfileSwitchingMethod(to method: SettingsModel.ProfileSwitching)
    /// Get the profile switching method from permanent storage.
    /// - Returns: The found method.
    func getProfileSwitchingMethod() -> SettingsModel.ProfileSwitching
}

/// Implementation of the `SettingsStorageProtocol`.
public final class SettingStorage: SettingsStorageProtocol {
    let basicStorage: BasicStorageProtocol
    
    init(basicStorage: BasicStorageProtocol) { self.basicStorage = basicStorage }
    
    public func setProfileSwitchingMethod(to method: SettingsModel.ProfileSwitching) {
        try? self.basicStorage.setSecureData(.userSwitchingMethod, data: method) // TODO: Fails silently
    }
    
    public func getProfileSwitchingMethod() -> SettingsModel.ProfileSwitching {
        return (try? self.basicStorage.getSecureData(.userSwitchingMethod)) ?? .askOnLaunch
    }
}
