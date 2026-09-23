//
//  APIBasicStorage.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

/// Available keys for interacting with the permanent storage.
public enum StorageKeys {
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

/// A protocol for abstracting access to local storage via key-value pairs
public protocol BasicStorageProtocol {
    /// Set a `String` into storage
    /// - Parameters:
    ///   - key: Location the `String` should be saved to
    ///   - value: The `String` itself
    func setString(_ key: StorageKeys, value: String)
    /// Set a `Bool` into storage
    /// - Parameters:
    ///   - key: Location the `Bool` should be saved to
    ///   - value: The `Bool` itself
    func setBool(_ key: StorageKeys, value: Bool)
    /// Set a `Numeric` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `Numeric` value itself
    func setNumber<T: Numeric>(_ key: StorageKeys, value: T?)
    /// Set a `RawRepresentable` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `RawRepresentable` value itself
    func setRepresentable<T: RawRepresentable>(_ key: StorageKeys, value: T)
    /// Set a `Codable` value into storage
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `Codable` value itself
    func setObject<T: Codable>(_ key: StorageKeys, value: T)
    /// Delete a key from storage
    /// - Parameter key: The key to delete
    func delete(_ key: StorageKeys)
    /// Get a `String` if it's available
    /// - Parameter key: Location of the desired `String`
    /// - Returns: The `String` if it was found
    func getString(_ key: StorageKeys) -> String?
    /// Get a `[String]` if it's available
    /// - Parameters:
    ///   - key: Location the value should be saved to
    ///   - value: The `[String]` itself
    func setStringArray(_ key: StorageKeys, value: [String]?)
    /// Get an array of `String` values if available
    /// - Parameter key: Location of the desired array
    /// - Returns: The array of `String` values if it was found
    func getStringArray(_ key: StorageKeys) -> [String]?
    /// Get a number if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The `Numeric` value if it was found
    func getNumber<T: Numeric>(_ key: StorageKeys) -> T?
    /// Get a `RawRepresentable` value if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The `RawRepresentable` value if it was found
    func getRepresentable<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String
    /// Get an object that can be decoded if it's available
    /// - Parameter key: Location of the desired value
    /// - Returns: The decoded object
    func getObject<T: Decodable>(_ key: StorageKeys) -> T?
    /// Allows setting the key to be saved both locally and in the cloud
    /// - Parameters:
    ///   - key: Key to update the value for
    ///   - local: Should this key only be saved locally or not
    func setKeyIsLocal(_ key: StorageKeys, local: Bool)
    /// Checks to see if the key is meant to be saved locally or in the cloud as well
    /// - Parameter key: Key to check
    /// - Returns: If the key is only stored locally or not
    func getKeyIsLocal(_ key: StorageKeys) -> Bool
    /// Batches of keys that changed outside this process, as the cloud reports them.
    /// Each access hands back its own stream, so several observers can watch at once without stealing each other's events.
    var externalChanges: AsyncStream<[StorageKeys]> { get }
}

/// Send cloud change notifications out to every interested observer.
/// Kept separate from `HybridBasicStorage` so it can be touched from the notification callback regardless of the storage's actor
/// isolation, which differs between the app and the Top Shelf extension.
/// `nonisolated` because the lock already guards the state, and stream termination can arrive on any actor.
/// Written by AI.
nonisolated private final class ExternalChangeBroadcaster: @unchecked Sendable {
    /// Guards `continuations`, which is read when an observer starts and written when one stops
    private let lock = NSLock()
    /// One continuation per live observer, keyed so each can remove itself once it stops listening
    private var continuations: [UUID: AsyncStream<[StorageKeys]>.Continuation] = [:]
    
    /// Hands out a stream carrying every future batch of changed keys.
    /// - Returns: A stream that only finishes when its consumer stops iterating
    func makeStream() -> AsyncStream<[StorageKeys]> {
        return AsyncStream { continuation in
            let id = UUID()
            self.lock.withLock { self.continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { _ = self.continuations.removeValue(forKey: id) }
            }
        }
    }
    
    /// Sends a batch of changed keys to every live observer.
    /// - Parameter keys: Keys that just changed outside this process
    func send(_ keys: [StorageKeys]) {
        let live = self.lock.withLock { Array(self.continuations.values) }
        for continuation in live { continuation.yield(keys) }
    }
}

/// Stores data locally and in the cloud
public final class HybridBasicStorage: BasicStorageProtocol {
    /// How storage gets synced
    private let cloudStore: NSUbiquitousKeyValueStore
    /// Data that remains local
    private let defaults: UserDefaults
    /// Fans incoming cloud changes out to every observer
    private let changeBroadcaster = ExternalChangeBroadcaster()
    /// Token for the cloud change observer, held so it lives as long as storage does
    private var changeObserver: NSObjectProtocol?
    
    /// Current major iteration of database storage
    public static let dbVersion: Int8 = 2
    /// Key to read the version from in self.cloudStore
    private static let dbVersionKey: String = "dbVersion"
    /// Reused JSON encoder. Allocating a fresh coder per request is wasteful
    private static let jsonEncoder = JSONEncoder()
    /// Reused JSON decoder. Allocating a fresh coder per request is still wasteful
    private static let jsonDecoder = JSONDecoder()
    
    /// Sets up storage for local and cloud syncing
    public init() throws(BasicStorageErrors) {
        // Setup local storage
        guard let defaults = UserDefaults(suiteName: "group.com.benlab.stingray") // Use a group to sync with extensions (ex TopShelf)
        else { throw .userDefaultsSetup }
        self.defaults = defaults
        
        // Setup cloud storage
        self.cloudStore = NSUbiquitousKeyValueStore.default // Setup key-value store
        self.cloudStore.synchronize() // Get the latest data from iCloud
        if CommandLine.arguments.contains("-ResetICloud") && !(Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? true) {
            Log.critical("Resetting iCloud...")
            for key in self.cloudStore.dictionaryRepresentation.keys {
                self.cloudStore.removeObject(forKey: key)
            }
            self.cloudStore.synchronize()
            self.defaults.synchronize()
            Log.critical("Reset complete. DB Version: \(self.defaults.integer(forKey: Self.dbVersionKey))")
        }
        
        // Which profile is in use is a per-device choice, so it must never travel between Apple TVs
        self.setKeyIsLocal(.defaultStreamingUserID, local: true)
        
        self.observeCloudChanges()
    }
    
    public func getKeyIsLocal(_ key: StorageKeys) -> Bool {
        if Bundle.main.bundleIdentifier?.hasSuffix("TopShelf") ?? false { // iCloud often isn't fast enough for the TopShelf
            return true
        }
        return self.defaults.bool(forKey: "Local\(key.rawValue)")
    }
    
    public func setKeyIsLocal(_ key: StorageKeys, local: Bool) {
        self.defaults.set(local, forKey: "Local\(key.rawValue)")
    }
    
    public var externalChanges: AsyncStream<[StorageKeys]> { self.changeBroadcaster.makeStream() }
    
    /// Starts watching for values the cloud changed underneath us.
    /// Registered during setup, since the initial-sync notification arrives shortly after launch and is easy to miss.
    private func observeCloudChanges() {
        self.changeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: self.cloudStore,
            queue: .main // Observers drive SwiftUI state, and the cloud posts this on an arbitrary queue
        ) { [weak self] notification in
            self?.handleCloudChange(notification)
        }
    }
    
    /// Mirrors changed cloud values into local storage, then tells observers which keys moved.
    /// - Parameter notification: The change notification the cloud posted
    private func handleCloudChange(_ notification: Notification) {
        let userInfo = notification.userInfo
        if userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int == NSUbiquitousKeyValueStoreQuotaViolationChange {
            Log.critical("iCloud key-value storage is over quota, so the last write was rejected")
            return
        }
        
        // An initial sync or an account change can replace the whole store, and reports no specific keys
        let rawKeys = userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            ?? Array(self.cloudStore.dictionaryRepresentation.keys)
        
        var changed: [StorageKeys] = []
        for rawKey in rawKeys {
            guard let key = StorageKeys(rawValue: rawKey),
                  !self.getKeyIsLocal(key) // A local-only key must never be clobbered by a stale cloud copy
            else { continue }
            // Keep the local mirror current, since the TopShelf only ever reads locally
            self.defaults.set(self.cloudStore.object(forKey: rawKey), forKey: rawKey)
            changed.append(key)
        }
        
        guard !changed.isEmpty else { return }
        self.changeBroadcaster.send(changed)
    }
    
    /// Directly interfaces with storage systems to set values.
    /// This is intended to be called by other functions that filter types to be known-safe during runtime
    /// - Parameters:
    ///   - key: Location to save values
    ///   - value: Value to save
    private func simpleSet(_ key: StorageKeys, value: Any?) {
        if !self.getKeyIsLocal(key) { self.cloudStore.set(value, forKey: key.rawValue) }
        self.defaults.set(value, forKey: key.rawValue)
    }
    
    public func setString(_ key: StorageKeys, value: String) { self.simpleSet(key, value: value) }
    
    public func setStringArray(_ key: StorageKeys, value: [String]?) { self.simpleSet(key, value: value) }
    
    public func setBool(_ key: StorageKeys, value: Bool) { self.simpleSet(key, value: value) }
    
    public func setNumber<T: Numeric>(_ key: StorageKeys, value: T?) { self.simpleSet(key, value: value) }
    
    public func setRepresentable<T: RawRepresentable>(_ key: StorageKeys, value: T) { self.simpleSet(key, value: value.rawValue) }
    
    public func setObject<T: Codable>(_ key: StorageKeys, value: T) {
        guard let data = try? Self.jsonEncoder.encode(value).base64EncodedString()
        else { return }
        self.simpleSet(key, value: data)
    }
    
    public func delete(_ key: StorageKeys) {
        self.defaults.removeObject(forKey: key.rawValue)
        if !self.getKeyIsLocal(key) { self.cloudStore.removeObject(forKey: key.rawValue) }
    }
    
    public func getString(_ key: StorageKeys) -> String? {
        let result: String?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.string(forKey: key.rawValue) }
        else { result = self.defaults.string(forKey: key.rawValue) }
        return result == "" ? nil : result
    }
    
    public func getStringArray(_ key: StorageKeys) -> [String]? {
        let result: [String]?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.array(forKey: key.rawValue) as? [String] }
        else { result = self.defaults.stringArray(forKey: key.rawValue) }
        return result?.isEmpty ?? false ? nil : result
    }
    
    public func getNumber<T: Numeric>(_ key: StorageKeys) -> T? {
        let result: Any?
        if !self.getKeyIsLocal(key) { result = self.cloudStore.object(forKey: key.rawValue) }
        else { result = self.defaults.object(forKey: key.rawValue) }
        
        return result as? T
    }
    
    public func getRepresentable<T: RawRepresentable>(_ key: StorageKeys) -> T? where T.RawValue == String {
        let raw: String? = self.getString(key) // We get empty safety by reusing our functions
        if let raw { return T(rawValue: raw) }
        else { return nil }
    }
    
    public func getObject<T: Decodable>(_ key: StorageKeys) -> T? {
        guard let encoded: String = self.getString(key),
              let data: Data = Data(base64Encoded: encoded)
        else { return nil }
        
        return try? Self.jsonDecoder.decode(T.self, from: data)
    }
}
