//
//  TVProfileManager.swift
//  Stingray
//
//  Manages Apple TV profile integration with Jellyfin users.
//  When tvOS profile switches, the app relaunches - this manager
//  handles auto-selecting the correct Jellyfin user on launch.
//

import Foundation
#if os(tvOS)
import TVUIKit
#endif

/// Manages the mapping between Apple TV profiles and Jellyfin users
@Observable
final class TVProfileManager {
    /// Shared instance for app-wide access
    static let shared = TVProfileManager()
    
    /// The current Apple TV profile identifier (nil if profiles not enabled)
    private(set) var currentATVProfileID: String?
    
    /// Whether Apple TV multi-user profiles are available
    private(set) var isProfilesAvailable: Bool = false
    
    private let storage: BasicStorageProtocol
    
    private init(storage: BasicStorageProtocol = DefaultsBasicStorage()) {
        self.storage = storage
        updateCurrentProfile()
    }
    
    // MARK: - Profile Detection
    
    private func updateCurrentProfile() {
        #if os(tvOS)
        let userManager = TVUserManager()
        if let identifier = userManager.currentUserIdentifier {
            currentATVProfileID = identifier.uuidString
            isProfilesAvailable = true
            print("TVProfileManager: Current ATV Profile ID: \(identifier.uuidString)")
        } else {
            currentATVProfileID = nil
            isProfilesAvailable = false
            print("TVProfileManager: No ATV Profile detected (single-user or profiles disabled)")
        }
        #else
        currentATVProfileID = nil
        isProfilesAvailable = false
        #endif
    }
    
    // MARK: - Profile Mapping
    
    /// Get the Jellyfin user ID mapped to an Apple TV profile
    func getMappedJellyfinUser(forATVProfile atvProfileID: String) -> String? {
        let mappings = getProfileMappings()
        return mappings[atvProfileID]
    }
    
    /// Get the Apple TV profile ID mapped to a Jellyfin user
    func getMappedATVProfile(forJellyfinUser jellyfinUserID: String) -> String? {
        let mappings = getProfileMappings()
        return mappings.first(where: { $0.value == jellyfinUserID })?.key
    }
    
    /// Link the current Apple TV profile to a Jellyfin user
    /// - Parameter jellyfinUserID: The Jellyfin user ID to link
    /// - Returns: True if linking was successful
    @discardableResult
    func linkCurrentProfileToUser(_ jellyfinUserID: String) -> Bool {
        guard let profileID = currentATVProfileID else {
            print("TVProfileManager: Cannot link - no ATV profile detected")
            return false
        }
        
        var mappings = getProfileMappings()
        
        // Remove any existing mapping for this Jellyfin user (one-to-one mapping)
        mappings = mappings.filter { $0.value != jellyfinUserID }
        
        // Add the new mapping
        mappings[profileID] = jellyfinUserID
        saveProfileMappings(mappings)
        
        print("TVProfileManager: Linked ATV profile to Jellyfin user \(jellyfinUserID)")
        return true
    }
    
    /// Unlink the current Apple TV profile from any Jellyfin user
    func unlinkCurrentProfile() {
        guard let profileID = currentATVProfileID else { return }
        
        var mappings = getProfileMappings()
        mappings.removeValue(forKey: profileID)
        saveProfileMappings(mappings)
        
        print("TVProfileManager: Unlinked current ATV profile")
    }
    
    /// Unlink a specific Jellyfin user from any Apple TV profile
    func unlinkUser(_ jellyfinUserID: String) {
        var mappings = getProfileMappings()
        let hadMapping = mappings.contains(where: { $0.value == jellyfinUserID })
        mappings = mappings.filter { $0.value != jellyfinUserID }
        saveProfileMappings(mappings)
        
        if hadMapping {
            print("TVProfileManager: Unlinked Jellyfin user \(jellyfinUserID)")
        }
    }
    
    /// Check if the current Apple TV profile is linked to any Jellyfin user
    var isCurrentProfileLinked: Bool {
        guard let profileID = currentATVProfileID else { return false }
        return getMappedJellyfinUser(forATVProfile: profileID) != nil
    }
    
    /// Check if a specific Jellyfin user is linked to the current Apple TV profile
    func isUserLinkedToCurrentProfile(_ jellyfinUserID: String) -> Bool {
        guard let profileID = currentATVProfileID else { return false }
        return getMappedJellyfinUser(forATVProfile: profileID) == jellyfinUserID
    }
    
    /// Check if a Jellyfin user is linked to any ATV profile
    func isUserLinked(_ jellyfinUserID: String) -> Bool {
        return getMappedATVProfile(forJellyfinUser: jellyfinUserID) != nil
    }
    
    // MARK: - Storage Helpers
    
    private func getProfileMappings() -> [String: String] {
        guard let jsonString = storage.getString(.atvProfileMapping, id: ""),
              let data = jsonString.data(using: .utf8),
              let mappings = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return mappings
    }
    
    private func saveProfileMappings(_ mappings: [String: String]) {
        if let data = try? JSONEncoder().encode(mappings),
           let jsonString = String(data: data, encoding: .utf8) {
            storage.setString(.atvProfileMapping, id: "", value: jsonString)
        }
    }
    
    // MARK: - Auto-Login Support
    
    /// Get the Jellyfin user that should be auto-logged in based on the current ATV profile.
    /// Returns nil if no profile is active or no mapping exists.
    func getAutoLoginUser() -> User? {
        guard let profileID = currentATVProfileID,
              let jellyfinUserID = getMappedJellyfinUser(forATVProfile: profileID) else {
            return nil
        }
        
        let userModel = UserModel()
        return userModel.getUsers().first(where: { $0.id == jellyfinUserID })
    }
    
    /// Determine which user should be used on app launch.
    /// Priority: 1) ATV profile mapped user, 2) Default user
    func getUserForAppLaunch() -> User? {
        // First, try to get a user based on ATV profile mapping
        if let profileUser = getAutoLoginUser() {
            print("TVProfileManager: Using ATV profile-mapped user: \(profileUser.displayName)")
            return profileUser
        }
        
        // Fall back to the default user
        let userModel = UserModel()
        if let defaultUser = userModel.getDefaultUser() {
            print("TVProfileManager: Using default user: \(defaultUser.displayName)")
            return defaultUser
        }
        
        return nil
    }
}
