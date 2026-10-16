//
//  TopShelfCredentials.swift
//  TopShelf
//
//  Created by Ben Roberts on 10/16/26.
//

import Foundation

/// Keeping this about as small as possible, just storing the `serviceURL` and `accessToken`.
struct TopShelfCredentials: Decodable {
    /// Address of the active user's server
    let serviceURL: URL
    /// Token authenticating the active user's requests
    let accessToken: String

    /// Picks the server address and access token out of a stored user, ignoring everything else.
    /// - Parameter decoder: JSON decoder
    /// - Throws: `DecodingError` if the user is missing either field, or belongs to a service the extension doesn't know
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StoredUserKeys.self)
        self.serviceURL = try container.decode(URL.self, forKey: .serviceURL)

        let serviceType = try container.nestedContainer(keyedBy: StoredServiceTypeKeys.self, forKey: .serviceType)
        let type = try? serviceType.decode(String.self, forKey: .type)
        if type != "Jellyfin" {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: serviceType,
                debugDescription: "Unknown service type: \(type ?? "none provided")"
            )
        }
        let jellyfin = try serviceType.nestedContainer(keyedBy: StoredJellyfinKeys.self, forKey: .jellyfinData)
        self.accessToken = try jellyfin.decode(String.self, forKey: .accessToken)
    }

    /// ID of the active user, as the app stores it on this device.
    static var activeUserID: String? {
        let userID = UserDefaults(suiteName: StorageKeys.appGroup)?.string(forKey: StorageKeys.defaultStreamingUserID.rawValue)
        return userID == "" ? nil : userID
    }

    /// Reads the active user's credentials from the app's stored user.
    /// - Returns: The credentials, or `nil` if nobody is signed in or the user couldn't be read
    static func load() -> TopShelfCredentials? {
        guard let userID = Self.activeUserID,
              let encoded = UserDefaults(suiteName: StorageKeys.appGroup)?.string(forKey: StorageKeys.user(userID).rawValue),
              let data = Data(base64Encoded: encoded) // Users are stored as base64 encoded JSON
        else { return nil }
        return try? JSONDecoder().decode(TopShelfCredentials.self, from: data)
    }
}
