//
//  StreamingServiceBasicModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

/// A basic protocol for must-have streaming-service related content
public protocol StreamingServiceBasicProtocol {
    /// Retrieves a list of recently added media
    /// - Parameter contentType: The type of media to retrieve
    /// - Returns: All slim versions of media found
    func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [SlimMedia]
    
    /// Retrieves a list of the media slated for up next
    /// - Returns: All slim versions of media found
    func retrieveUpNext() async -> [SlimMedia]
}

/// Denotes types of desired media for recently added content
public enum RecentlyAddedMediaType {
    /// Get a list of recently added movies
    case movie
    /// Get a list of recently added TV Shows
    case tv
    /// Get a list of all recently added content
    case all
}

