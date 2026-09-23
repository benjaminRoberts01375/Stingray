//
//  StreamingService.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

/// A cut-down streaming service for the Top Shelf extension.
/// Implements only the two protocols the extension renders from, so it can be built and queried without the app's full library sync.
public final class StreamingServiceBasicModel: MediaImageProviding & RecommendationProviding {
    /// Network used to reach the server
    private var networkAPI: TopShelfNetworkProtocol
    /// Access token for the active user
    private var accessToken: String
    
    /// Builds a service for whichever user is currently active.
    /// - Parameter userModel: Store to read the active user from
    /// - Throws: `StreamingServiceErrors.initFailed` wrapping `.noDefaultUser` when nobody is signed in
    init(userModel: UserModel) throws(StreamingServiceErrors) {
        let defaultUser: any UserProtocol
        do {
            if let maybeUser = userModel.activeUser { defaultUser = maybeUser }
            else { throw StreamingServiceErrors.noDefaultUser }
        }
        catch { throw StreamingServiceErrors.initFailed(error) }
        
        switch defaultUser.serviceType {
        case .Jellyfin(let userJellyfin):
            let network = APINetwork(network: JellyfinBasicNetwork(address: defaultUser.serviceURL))
            self.networkAPI = network
            self.accessToken = userJellyfin.accessToken
        }
    }
    
    /// Get all the recently added media. contentType is ignored
    /// - Parameter contentType: Ignored
    /// - Returns: All recently added media
    public func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [MediaModelRepresentable] {
        do { return try await networkAPI.getRecentlyAdded(accessToken: accessToken) }
        catch { return [] }
    }
    
    public func retrieveUpNext() async -> [MediaModelRepresentable] {
        do {
            guard let upNext = try await networkAPI.getUpNext(accessToken: accessToken).first else { return [] }
            return [upNext]
        } catch {
            return []
        }
    }
    
    public func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, mediaID: mediaID, width: width)
    }
}
