//
//  APINetwork.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

public protocol AdvancedNetworkProtocol {
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
}

public struct APINetwork: AdvancedNetworkProtocol {
    var network: BasicNetworkProtocol
    
    public func getRecentlyAdded(accessToken: String) async throws -> [SlimMedia] {
        return []
    }
    
    public func getUpNext(accessToken: String) async throws -> [SlimMedia] {
        return []
    }
}
