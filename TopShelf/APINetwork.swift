//
//  APINetwork.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

public protocol TopShelfNetworkProtocol {
    /// Retrieve recently added media of some type
    /// - Parameters:
    ///   - contentType: Type of media to retrieve
    ///   - accessToken: Access token for the server
    /// - Returns: A silm verion of the media type
    func getRecentlyAdded(accessToken: String) async throws -> [SlimMedia]
    
    /// Gets up next shows
    /// - Parameter accessToken: Access token for the server
    /// - Returns: Available media for up next
    func getUpNext(accessToken: String) async throws -> [SlimMedia]
    
    /// Generates a URL for an image
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - imageType: Type of image (ex. poster)
    ///   - mediaID: ID of the image
    ///   - width: Ideal width of the image
    /// - Returns: Formatted URL if possible
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL?
}

public struct APINetwork: TopShelfNetworkProtocol {
    var network: BasicNetworkProtocol
    
    public func getRecentlyAdded(accessToken: String) async throws -> [SlimMedia] {
        let params: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(25)"),
            URLQueryItem(name: "fields", value: "ParentId")
        ]
        
        return try await network.request(
            verb: .get,
            path: "/Items/Latest",
            headers: ["X-MediaBrowser-Token": accessToken],
            urlParams: params,
            body: nil
        )
    }
    
    public func getUpNext(accessToken: String) async throws -> [SlimMedia] {
        struct Root: Decodable {
            let Items: [SlimMedia]
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
