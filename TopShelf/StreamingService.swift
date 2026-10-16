//
//  StreamingService.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

/// A cut-down streaming service for the Top Shelf extension.
/// Built from the credentials the app leaves behind, so it can be queried without the app's users or full library sync.
final class TopShelfService {
    /// Network used to reach the server
    private let networkAPI: TopShelfNetworkProtocol
    /// Access token for the active user
    private let accessToken: String

    /// Builds a service for whichever user was last active in the app.
    /// - Parameter credentials: Server details for the active user
    init(credentials: TopShelfCredentials) {
        self.networkAPI = APINetwork(network: JellyfinBasicNetwork(address: credentials.serviceURL))
        self.accessToken = credentials.accessToken
    }

    /// Get all the recently added media.
    /// - Returns: All recently added media, or nothing if the request failed
    func retrieveRecentlyAdded() async -> [TopShelfItem] {
        do { return try await networkAPI.getRecentlyAdded(accessToken: accessToken) }
        catch { return [] }
    }

    /// Get the next show to continue watching.
    /// - Returns: The first up next item, or nothing if there isn't one or the request failed
    func retrieveUpNext() async -> [TopShelfItem] {
        do {
            guard let upNext = try await networkAPI.getUpNext(accessToken: accessToken).first else { return [] }
            return [upNext]
        }
        catch { return [] }
    }

    /// Formats a URL for a piece of media's artwork.
    /// - Parameters:
    ///   - imageType: Shape of image
    ///   - mediaID: The media to get the image for
    ///   - width: Target width of the image
    /// - Returns: A formatted URL to the image
    func getImageURL(imageType: TopShelfImageType, mediaID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(imageType: imageType, mediaID: mediaID, width: width)
    }
}
