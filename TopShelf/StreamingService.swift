//
//  StreamingService.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

public final class StreamingServiceBasicModel: StreamingServiceBasicProtocol {
    private var networkAPI: AdvancedNetworkProtocol
    private var accessToken: String
    
    init() throws {
        guard let defaultUser = UserModel().getDefaultUser() else {
            throw InitError.noDefaultUser
        }
        switch defaultUser.serviceType {
        case .Jellyfin(let userJellyfin):
            let network = APINetwork(network: JellyfinBasicNetwork(address: defaultUser.serviceURL))
            self.networkAPI = network
            self.accessToken = userJellyfin.accessToken
        }
    }
    
    enum InitError: Error {
        case badAddress
        case noToken
        case noDefaultUser
    }
    
    public func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [SlimMedia] {
        do {
            return try await networkAPI.getRecentlyAdded(accessToken: accessToken)
        } catch {
            return []
        }
    }
    
    public func retrieveUpNext() async -> [SlimMedia] {
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
