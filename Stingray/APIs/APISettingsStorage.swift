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
    /// Gets the current maximum video bitrate. Nil = unlimited.
    /// - Returns: Video bitrate in bits per second. Nil = unlimited.
    func getBitrateCap() -> Int?
    /// Sets the maximum video bitrate
    /// - Parameter bitrate:Video bitrate in bits per second. Nil = unlimited.
    func setBitrateCap(_ bitrate: Int?)
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
    
    public func getBitrateCap() -> Int? {
        let bitrate = self.basicStorage.getInt(.maxBitrate)
        if bitrate == 0 { return nil }
        return bitrate
    }
    
    public func setBitrateCap(_ bitrate: Int?) {
        self.basicStorage.setInt(.maxBitrate, value: bitrate)
    }
}
