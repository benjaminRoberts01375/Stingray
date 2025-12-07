//
//  BasicStorageProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public enum BasicNetworkKeys: String {
    case serverURL = "serverURL"
    case usersName = "usersName"
    case userID = "userID"
    case sessionID = "sessionID"
    case accessToken = "accessToken"
    case serverID = "serverID"
}

public protocol BasicStorageProtocol {
    
    func getString(_ key: BasicNetworkKeys) -> String?
    func setString(_ key: BasicNetworkKeys, value: String)
    func getURL(_ key: BasicNetworkKeys) -> URL?
    func setURL(_ key: BasicNetworkKeys, value: URL?)
    func setBool(_ key: BasicNetworkKeys, value: Bool)
    func getBool(_ key: BasicNetworkKeys) -> Bool
}

public protocol AdvancedStorageProtocol {
    func getServerURL() -> URL?
    func setServerURL(_ url: URL)
    func getUsersName() -> String?
    func setUsersName(_ name: String?)
    func getUserID() -> String?
    func setUserID(_ id: String?)
    func getSessionID() -> String?
    func setSessionID(_ id: String?)
    func getAccessToken() -> String?
    func setAccessToken(_ token: String?)
    func getServerID() -> String?
    func setServerID(_ id: String?)
}

final class DefaultsBasicStorage: BasicStorageProtocol {
    private let defaults = UserDefaults.standard
    
    func getString(_ key: BasicNetworkKeys) -> String? {
        return defaults.string(forKey: key.rawValue)
    }
    
    func setString(_ key: BasicNetworkKeys, value: String) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getURL(_ key: BasicNetworkKeys) -> URL? {
        return URL(string: defaults.string(forKey: key.rawValue) ?? "")
    }
    
    func setURL(_ key: BasicNetworkKeys, value: URL?) {
        defaults.set(value?.absoluteString ?? "", forKey: key.rawValue)
    }
    
    func getBool(_ key: BasicNetworkKeys) -> Bool {
        return defaults.bool(forKey: key.rawValue)
    }
    
    func setBool(_ key: BasicNetworkKeys, value: Bool) {
        defaults.set(value, forKey: key.rawValue)
    }
}

final class DefaultsAdvancedStorage: AdvancedStorageProtocol {
    var storage: BasicStorageProtocol
    
    init(storage: BasicStorageProtocol) {
        self.storage = storage
    }
    
    func getServerURL() -> URL? {
        return storage.getURL(.serverURL)
    }
    func setServerURL(_ url: URL) {
        print("Advanced Storage: Setting URL: \(url.absoluteString)")
        storage.setURL(.serverURL, value: url)
    }
    
    func getUsersName() -> String? {
        return storage.getString(.usersName)
    }
    func setUsersName(_ name: String?) {
        storage.setString(.usersName, value: name ?? "")
    }
    
    func getUserID() -> String? {
        return storage.getString(.userID)
    }
    func setUserID(_ id: String?) {
        storage.setString(.userID, value: id ?? "")
    }
    
    func getSessionID() -> String? {
        return storage.getString(.sessionID)
    }
    func setSessionID(_ id: String?) {
        storage.setString(.sessionID, value: id ?? "")
    }
    
    func getAccessToken() -> String? {
        return storage.getString(.accessToken)
    }
    func setAccessToken(_ token: String?) {
        storage.setString(.accessToken, value: token ?? "")
    }
    
    func getServerID() -> String? {
        return storage.getString(.serverID)
    }
    
    func setServerID(_ id: String?) {
        storage.setString(.serverID, value: id ?? "")
    }
}
