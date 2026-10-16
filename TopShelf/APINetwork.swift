//
//  APINetwork.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

/// The slice of the server API the Top Shelf extension needs.
///
/// Deliberately narrower than the app's `AdvancedNetworkProtocol`: the extension has a tight launch budget, so it only fetches the two
/// recommendation rows and the artwork URLs required to render them.
public protocol TopShelfNetworkProtocol {
    /// Retrieve recently added media of any type
    /// - Parameter accessToken: Access token for the server
    /// - Returns: A slim version of each media item
    func getRecentlyAdded(accessToken: String) async throws -> [MediaStorage]
    
    /// Gets up next shows
    /// - Parameter accessToken: Access token for the server
    /// - Returns: Available media for up next
    func getUpNext(accessToken: String) async throws -> [MediaStorage]
    
    /// Generates a URL for an image
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - imageType: Type of image (ex. poster)
    ///   - mediaID: ID of the image
    ///   - width: Ideal width of the image
    /// - Returns: Formatted URL if possible
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL?
}

/// Jellyfin implementation of `TopShelfNetworkProtocol`, built on the app's shared `BasicNetworkProtocol`.
public struct APINetwork: TopShelfNetworkProtocol {
    /// Transport used for every request
    var network: BasicNetworkProtocol
    
    public func getRecentlyAdded(accessToken: String) async throws -> [MediaStorage] {
        let params: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(25)"),
            URLQueryItem(name: "fields", value: "ParentId")
        ]
        
        let items: [MediaStorage] = try await network.request(
            verb: .get,
            path: "/Items/Latest",
            headers: ["X-MediaBrowser-Token": accessToken],
            urlParams: params,
            body: nil
        )
        return items
    }
    
    public func getUpNext(accessToken: String) async throws -> [MediaStorage] {
        struct Root: Decodable {
            let Items: [MediaStorage]
        }
        
        let params: [URLQueryItem] = [ URLQueryItem(name: "fields", value: "ParentId") ]
        
        let root: Root = try await network.request(
            verb: .get,
            path: "/Shows/NextUp",
            headers: ["X-MediaBrowser-Token": accessToken],
            urlParams: params,
            body: nil
        )
        return root.Items
    }
    
    public func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        let params : [URLQueryItem] = [
            URLQueryItem(name: "fillWidth", value: String(width)),
            URLQueryItem(name: "quality", value: "95")
        ]
        
        return network.buildURL(path: "/Items/\(mediaID)/Images/\(imageType.rawValue)", urlParams: params)
    }
}
