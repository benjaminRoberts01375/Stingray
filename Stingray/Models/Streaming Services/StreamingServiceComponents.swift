//
//  StreamingServiceComponents.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/26.
//

/// Describes the current setup status for a downloaded library
public enum LibraryStatus {
    /// The library object has been created and is fetching
    case retrieving
    /// Some of the library's content is available, but we're still fetching
    case available([LibraryModel])
    /// All of this library's content has been downloaded
    case complete([LibraryModel])
    /// The library has errored out
    case error(RError)
}

/// Denotes the availablity of a piece of media
public enum MediaLookupStatus {
    /// The requested media was found
    case found(MediaStorage)
    /// The requested media was not found, but may be available once libraries finish downloading
    case temporarilyNotFound
    /// The requested media was not found despite all libraries being downloaded
    case notFound
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

/// Denotes types of desired media for recently added content
public enum RecentlyAddedMediaType {
    /// Get a list of recently added movies
    case movie
    /// Get a list of recently added TV Shows
    case tv
    /// Get a list of all recently added content
    case all
}
