//
//  StreamingServiceProtocols.swift
//  Stingray
//
//  Created by Ben Roberts on 12/11/25.
//

import AVFoundation

/// Requires this type to be able to request an image
public protocol MediaImageProviding {
    /// Formats a URL based on a piece of media
    /// - Parameters:
    ///   - imageType: Shape of image
    ///   - mediaID: The mediaID of the media to get the image for
    ///   - width: Target width of the image
    /// - Returns: A formatted URL to the image
    func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL?
}

/// Allows retrieval of recommendations for the user
public protocol RecommendationProviding {
    /// Retrieves a list of recently added media
    /// - Parameter contentType: The type of media to retrieve
    /// - Returns: All media found. These are slim versions that lack details like media sources and seasons
    func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [MediaStorage]
    
    /// Retrieves a list of the media slated for up next
    /// - Returns: All media found. These are slim versions that lack details like media sources and seasons
    func retrieveUpNext() async -> [MediaStorage]
}

/// Basic information about the connected server
public protocol SystemInfoProviding {
    /// Name of the server
    var serverName: String? { get }
    /// Version of software the server is running
    var serverVersion: String? { get }
    /// Base path of the service.
    var serviceURL: URL { get }
}

/// Holds information about the available libraries
public protocol LibraryProviding {
    /// Denote the current fetching status of this library. If (partially) complete this holds library data, otherwise may hold an error.
    var libraryStatus: LibraryStatus { get }
    /// Resync a given library with the server
    /// - Parameters:
    ///   - library: Library to resync
    ///   - flatten: Should data media within the library maintain their sub-folders, or group all media together
    func resync(library: any LibraryProtocol, flatten: Bool) async

    /// Fetch libraries and library media.
    /// - Parameters:
    ///   - flatten: Should media in sub-folders remain in sub-folders
    func retrieveLibraries(flatten: Bool) async
}

/// Holds info about media currently playing
public protocol PlayerProviding {
    /// Track the current playback progress.
    var playerProgress: PlayerProtocol? { get }

    /// Setup playback, informs the server about playback status
    /// - Parameters:
    ///   - mediaSource: Media source being watched.
    ///   - videoID: Video stream ID.
    ///   - audioID: Audio stream ID.
    ///   - subtitleID: Subtitle stream ID. Nil = no subtitles.
    ///   - bitrate: Target video bitrate of the stream. Nil = unlimited bitrate
    ///   - title: Title of the media to put on the player.
    ///   - subtitle: Subtitle, if available, to put on the player.
    ///   - player: An AVPlayer instance to update and use.
    func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Int?,
        title: String,
        subtitle: String?,
        player: AVPlayer
    )

    /// Inform the server that playback has ended
    func playbackEnd()
}

/// Provides user actions with the server
public protocol UserProviding {
    /// The name of the user.
    var usersName: String { get }
    /// The server ID of the user.
    var userID: String { get }

    /// Logout the current user
    func logout() async
}

/// Loading media functions
public protocol MediaProviding {
    /// Link a media ID to its `MediaStorage`.
    /// - Parameters:
    ///   - mediaID: Media ID to search for.
    ///   - parentID: Parent the Media ID is a part of (if available).
    /// - Returns: The found media, noting if the library is not yet finished fetching.
    func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus

    /// Fetch any additional data (ex special features) for this media.
    /// - Parameter media: Media to fetch for.
    /// - Parameter priority: How prudent the info is to get right now
    func getExtraMediaData(for media: any SpecialFeaturesProtocol & MediaMetadataProtocol, priority: RequestPriority)
}
