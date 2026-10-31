//
//  MediaProtocols.swift
//  Stingray
//
//  Created by Ben Roberts on 10/14/26.
//

import Foundation

/// General metadata that all media and media storage should have
public protocol MetadataProtocol: Identifiable, Displayable {
    /// Unique identifier for this media
    var id: String { get }
    /// The owner of this media
    var parentID: String { get }
    /// The name of the data
    var title: String { get }
    /// Title to use when running sorting algorithms
    var sortTitle: String { get }
    /// List of genres that describe the media. Ex `["Action", "Adventure", "Drama"]`
    var genres: Set<String> { get set }
}

/// The descriptive metadata shared by every kind of media, independent of how it is played.
public protocol MediaMetadataProtocol: Identifiable, MetadataProtocol {
    /// Rating of this media provided by the server. Ex PG, PG-13, R.
    var maturity: String? { get }
    /// Date the series first released. For shows with multiple episodes, this will be the date of the first episode.
    var releaseDate: Date? { get }
    /// Estimated runtime of the movie or per-episode.
    var duration: Duration? { get }
    /// A longer descriptor of the series
    var description: String { get }
    /// Those involved with the media in its entirety
    var people: [any MediaPersonProtocol] { get }
    /// Short descriptor of the media.
    var tagline: String? { get }
}

/// Media that can have special features. Ex. movies and TV shows, but not home videos.
public protocol SpecialFeaturesProtocol {
    /// Tracks if the special features have been fetched. If they have been successfully fetched, they'll available through this variable.
    var specialFeatures: SpecialFeaturesStatus { get }

    /// Load special features for this media
    func loadSpecialFeatures(specialFeatures: [SpecialFeature])
}

/// Describes how to hold data about a person for a piece of media
public protocol MediaPersonProtocol {
    /// ID of the person
    var id: String { get }
    /// Person's full name
    var name: String { get }
    /// How they contributed to the media.
    var role: String { get }
    /// Preview hashes
    var imageHashes: MediaImageBlurHashes? { get } // TODO: This should probably be a protocol
}

/// Track image IDs for a piece of media
public protocol MediaImagesProtocol {
    /// Thumbnail ID
    var thumbnail: String? { get }
    /// Logo ID
    var logo: String? { get }
    /// Primary image ID
    var primary: String? { get }
}

/// A simple protocol that ensures content has the expected image data.
public protocol Displayable: Identifiable {
    /// Set of strings to make a crude image with.
    var imageBlurHashes: (any MediaImagesProtocol)? { get }
    /// Set of strings to request fully detailed images with.
    var imageTags: (any MediaImagesProtocol)? { get }
    /// ID provided by the server.
    var id: String { get }
}

/// Special feature for a given media. Ex. BTS, extras, deleted scenes...
public protocol SpecialFeatureProtocol: Displayable {
    /// Feature type given by the server.
    var featureType: String { get }
    /// Data streams.
    var mediaSources: [any MediaSourceProtocol] { get }
}

/// Media contains at least one media source, like different versions of the same movie. Each version of the movie needs their own video,
/// audio, and subtitle streams, among other information.
public protocol MediaSourceProtocol: Identifiable {
    /// ID provided by the server
    var id: String { get }
    /// Name of the media source. Ex. different versions of the same movie.
    var name: String { get }
    /// All available video streams for the source.
    var videoStreams: [any MediaStreamProtocol] { get }
    /// All available audio streams for the source. Ex. Different languages
    var audioStreams: [any MediaStreamProtocol] { get }
    /// All available subtitle streams for the source. Ex. Different languages, signs and songs, etc.
    var subtitleStreams: [any MediaStreamProtocol] { get }
    /// Where in the media source to begin playback.
    var startPoint: TimeInterval { get set }
    /// How long this media source is.
    var duration: TimeInterval { get }
}

/// Extend the MediaSourceProtocol to allow for getting similar streams
extension MediaSourceProtocol {
    /// Gets a streams based on stream type and title. This is good for having an existing stream for an episode, and finding a similar one
    /// for the next episode.
    /// - Parameters:
    ///   - baseStream: Initial stream to pull metadata from.
    ///   - streamType: Desired type of stream.
    /// - Returns: A potential matching stream.
    public func getSimilarStream(baseStream: any MediaStreamProtocol, streamType: StreamType) -> (any MediaStreamProtocol)? {
        var streams: [any MediaStreamProtocol]
        switch streamType {
        case .video: streams = videoStreams
        case .audio: streams = audioStreams
        case .subtitle: streams = subtitleStreams
        case .unknown: return nil
        }
        return streams.first { $0.title == baseStream.title }
    }
}

/// Describes how to hold information regarding a stream's metadata.
public protocol MediaStreamProtocol: Identifiable {
    /// ID of the media stream given by the server.
    var id: String { get }
    /// Title of the media stream. Ex. for subtitles it may read "English [CC]"
    var title: String { get }
    /// Quickly track what this stream is. Ex. video, audio, subtitles.
    var type: StreamType { get }
    /// The bitrate of the stream. Ex. The bitrate for a video stream may be 40,000 Kb/sec.
    var bitrate: Int { get }
    /// Encoding the stream is using. Ex. The codec for a video stream may be H.264, HEVC, AV9, or VP9.
    var codec: String { get }
    /// Is considered the default stream by the server.
    var isDefault: Bool { get }
}
