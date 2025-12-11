//
//  StreamingService.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

public final class StreamingServiceBasicModel: StreamingServiceBasicProtocol {
    private var networkAPI: AdvancedNetworkProtocol
    private var storageAPI: AdvancedStorageProtocol
    private var accessToken: String
    
    init() throws {
        let storage = DefaultsAdvancedStorage(storage: DefaultsBasicStorage())
        guard let url = storage.getServerURL() else {
            print("No URL")
            enum AddressError: Error { case badAddress }
            throw AddressError.badAddress
        }
        guard let token = storage.getAccessToken() else {
            print("No token")
            enum TokenError: Error { case noToken }
            throw TokenError.noToken
        }
        let network = APINetwork(network: JellyfinBasicNetwork(address: url))
        self.networkAPI = network
        self.storageAPI = storage
        self.accessToken = token
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

