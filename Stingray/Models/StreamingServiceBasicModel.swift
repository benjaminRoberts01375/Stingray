//
//  StreamingServiceBasicModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/11/25.
//

import Foundation

/// Requires this type to be able to request an image
public protocol MediaImageProviding {
    /// Formats a URL based on a piece of media
    /// - Parameters:
    ///   - imageType: Shape of image
    ///   - mediaID: The mediaID of the media to get the image for
    ///   - width: Target width of hte image
    /// - Returns: A formatted URL to the image
    func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL?
}

/// Denotes the type of image desired. Ex. a horizontal vs vertical movie poster image.
public enum MediaImageType: String {
    /// Fancy text of the media's name.
    case logo = "Logo"
    /// The most frequently used media image type. A vertical movie poster
    case primary = "Primary"
    /// A more action-packed horizontal image of the media
    case backdrop = "Backdrop"
}

/// Allows retrieval of recommendations for the user
public protocol RecommendationProviding {
    /// Retrieves a list of recently added media
    /// - Parameter contentType: The type of media to retrieve
    /// - Returns: All slim versions of media found
    func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [MediaModelRepresentable]

    /// Retrieves a list of the media slated for up next
    /// - Returns: All slim versions of media found
    func retrieveUpNext() async -> [MediaModelRepresentable]
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
