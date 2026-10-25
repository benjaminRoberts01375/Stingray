//
//  MediaModelComponents.swift
//  Stingray
//
//  Created by Ben Roberts on 10/14/26.
//

import Foundation

/// A basic wrapper around media types for quickly determining what type of media is presented. These are meant to be quite finely
/// defined, so a home video is separate from a home video, libraries are separate from playlists which are separate from collections, etc.
@dynamicMemberLookup // Thanks AI for this little tip
public enum MediaStorage: Decodable, Hashable {
    /// Holds some movie type
    case movie(any MovieProtocol)
    /// Holds example media
    case example(any MovieProtocol)
    /// Holds some tv show type
    case tvShow(any TVShowProtocol)
    /// Holds some home video type
    case homeVideo(any HomeVideoProtocol)
    /// Holds multiple pieces of media
    case subfolder(any SubFolderProtocol)
    /// Represents a failure to create this media
    case error(RError)

    public enum CodingKeys: String, CodingKey {
        case mediaType = "Type"
    }

    /// A convenience variable for getting the underlying type
    public var media: (any MetadataProtocol)? {
        switch self {
        case .movie(let movie): return movie
        case .example(let example): return example
        case .tvShow(let tvShow): return tvShow
        case .homeVideo(let homeVideo): return homeVideo
        case .subfolder(let subfolder): return subfolder
        case .error: return nil
        }
    }

    /// The underlying media's descriptive metadata. `nil` for media without it, like subfolders.
    public var mediaMetadata: (any MediaMetadataProtocol)? {
        switch self {
        case .movie(let movie): return movie
        case .example(let example): return example
        case .tvShow(let tvShow): return tvShow
        case .homeVideo(let homeVideo): return homeVideo
        case .subfolder, .error: return nil
        }
    }
    
    /// Returns true if this media is a group of other media
    public var isGroup: Bool {
        switch self {
        case .movie, .example, .tvShow, .homeVideo, .error: return false
        case .subfolder: return true
        }
    }

    /// Forwards any property of `MediaProtocol` to the underlying value.
    public subscript<T>(dynamicMember keyPath: KeyPath<any MetadataProtocol, T>) -> T? {
        self.media?[keyPath: keyPath]
    }

    /// Forwards any optional property of `MediaProtocol` to the underlying value, flattening the result to a single optional.
    public subscript<T>(dynamicMember keyPath: KeyPath<any MetadataProtocol, T?>) -> T? {
        self.media?[keyPath: keyPath] ?? nil
    }

    /// The sort title of some media. Handles error case.
    public var sortTitle: String {
        switch self {
        case .movie(let movie): return movie.sortTitle
        case .example(let example): return example.sortTitle
        case .tvShow(let tvShow): return tvShow.sortTitle
        case .homeVideo(let homeVideo): return homeVideo.sortTitle
        case .subfolder(let subfolder): return subfolder.sortTitle
        case .error: return String(localized: "Unknown Title")
        }
    }

    /// The  title of some media. Handles error case.
    public var title: String {
        switch self {
        case .movie(let movie): return movie.title
        case .example(let example): return example.title
        case .tvShow(let tvShow): return tvShow.title
        case .homeVideo(let homeVideo): return homeVideo.title
        case .subfolder(let subfolder): return subfolder.title
        case .error: return String(localized: "Unknown Title")
        }
    }

    // Hashable conformance
    public static func == (lhs: MediaStorage, rhs: MediaStorage) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(self.media?.id) }

    /// Creates the matching media type from JSON. Media that is an unknown type or fails to decode becomes `.error` rather than throwing,
    /// so a single bad item doesn't take down the rest of a response.
    /// - Parameter decoder: JSON decoder
    /// - throws: `JSONError` if the media's type can't be determined at all.
    public init(from decoder: Decoder) throws(JSONError) {
        let container: KeyedDecodingContainer<MediaStorage.CodingKeys>
        do { container = try decoder.container(keyedBy: CodingKeys.self) }
        catch { throw JSONError.missingContainer("Base Container", "Media Storage") }

        let mediaType: String
        do { mediaType = try container.decode(String.self, forKey: .mediaType) }
        catch { throw JSONError.missingKey(CodingKeys.mediaType.stringValue, "Media Storage") }

        switch MediaType(jellyfinAPI: mediaType) {
        case .movie:
            do { self = .movie(try MovieModel(from: decoder)) }
            catch { self = .error(error) }
        case .tvShow, .episode: // Episodes (ex. from up next) are represented by the show they belong to
            do { self = .tvShow(try TVShowModel(from: decoder)) }
            catch { self = .error(error) }
        case .homeVideo:
            do { self = .homeVideo(try HomeVideoModel(from: decoder)) }
            catch { self = .error(error) }
        case .subFolder:
            do { self = .subfolder(try SubFolderModel(from: decoder)) }
            catch { self = .error(error) }
        case nil: self = .error(MediaError.unknownMediaType(mediaType))
        }
    }

    /// Media types as the server names them. Used for decoding media and requesting specific types from the server.
    public enum MediaType {
        /// A movie
        case movie
        /// A TV show
        case tvShow
        /// A single episode of a TV show
        case episode
        /// A home video
        case homeVideo
        /// A folder containing more media
        case subFolder
        
        /// Create a string for the Jellyfin API from a `MediaType`
        var jellyfinAPI: String {
            switch self {
            case .episode: return "Epsiode"
            case .homeVideo: return "Video"
            case .movie: return "Movie"
            case .subFolder: return "Folder"
            case .tvShow: return "Series"
            }
        }
        
        /// Create a `MediaType` from the Jellyfin API
        /// - Parameter jellyfinAPI: Value used by the Jellyfin API
        init?(jellyfinAPI: String) {
            if jellyfinAPI == "Episode" { self = .episode }
            else if jellyfinAPI == "Video" { self = .homeVideo }
            else if jellyfinAPI == "Movie" { self = .movie }
            else if jellyfinAPI == "Folder" { self = .subFolder }
            else if jellyfinAPI == "Series" { self = .tvShow }
            return nil
        }
    }
}

/// Holds information about a single person who worked on a piece of media.
@Observable
public final class MediaPerson: MediaPersonProtocol, Identifiable, Decodable {
    public var id: String
    public var name: String
    public var role: String
    public var imageHashes: MediaImageBlurHashes?

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case imageHashes = "ImageBlurHashes"
    }

    /// Create a `MediaPerson` from JSON. Every field falls back to a placeholder rather than failing the whole decode.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Anonymous"
            self.role = try container.decodeIfPresent(String.self, forKey: .role) ?? "Unknown Roll"
            self.imageHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageHashes)
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "MediaPerson") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "MediaPerson") }
            else { throw JSONError.failedJSONDecode("MediaPerson", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("MediaPerson", error) }
    }
}

/// Holds hashes used to generate preview images.
@Observable
public final class MediaImageBlurHashes: Decodable, Equatable, MediaImagesProtocol {
    public var primary: String?
    public var logo: String?
    public var thumbnail: String?

    public enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case logo = "Logo"
        case backdrop = "Backdrop"
    }

    public static func == (lhs: MediaImageBlurHashes, rhs: MediaImageBlurHashes) -> Bool {
        lhs.primary == rhs.primary &&
        lhs.logo == rhs.logo &&
        lhs.thumbnail == rhs.thumbnail
    }

    /// Create a `MediaImageBlurHashes` from JSON.
    /// The server nests each hash under an image-tag key, so only the first value of each map is kept.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.primary = try container.decodeIfPresent([String: String].self, forKey: .primary)?.values.first
            self.logo = try container.decodeIfPresent([String: String].self, forKey: .logo)?.values.first
            self.thumbnail = try container.decodeIfPresent([String: String].self, forKey: .backdrop)?.values.first
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "Media Image Blur Hash") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "Media Image Blur Hash") }
            else { throw JSONError.failedJSONDecode("Media Image Blur Hash", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("Media Image Blur Hash", error) }
    }
}

/// Holds information leading to particular images.
@Observable
public final class MediaImages: Decodable, Equatable, MediaImagesProtocol {
    // Equatable conformance
    public static func == (lhs: MediaImages, rhs: MediaImages) -> Bool {
        lhs.thumbnail == rhs.thumbnail &&
        lhs.logo == rhs.logo &&
        lhs.primary == rhs.primary
    }

    public var thumbnail: String?
    public var logo: String?
    public var primary: String?

    public enum CodingKeys: String, CodingKey {
        case thumbnail = "Thumb"
        case logo = "Logo"
        case primary = "Primary"
    }

    /// Create image tags directly, for placeholder and example media.
    /// - Parameters:
    ///   - thumbnail: Thumbnail image tag
    ///   - logo: Logo image tag
    ///   - primary: Primary, or poster, image tag
    public init(thumbnail: String?, logo: String?, primary: String?) {
        self.thumbnail = thumbnail
        self.logo = logo
        self.primary = primary
    }

    /// Create a `MediaImages` from JSON. A missing tag simply means the server has no image of that kind.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
            self.logo = try container.decodeIfPresent(String.self, forKey: .logo)
            self.primary = try container.decodeIfPresent(String.self, forKey: .primary)
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "MediaImages") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "MediaImages") }
            else { throw JSONError.failedJSONDecode("MediaImages", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("MediaImages", error) }
    }
}

/// Holds a singular special feature's information.
public final class SpecialFeature: SpecialFeatureProtocol, Decodable {
    public let id: String
    public var featureType: String
    public let mediaSources: [any MediaSourceProtocol]
    public var imageBlurHashes: (any MediaImagesProtocol)?
    public var imageTags: (any MediaImagesProtocol)?

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case featureType = "ExtraType"
        case sortTitle = "SortName"
        case mediaSources = "MediaSources"
        case imageBlurHashes = "ImageBlurHashes"
        case imageTags = "ImageTags"
    }

    /// Create a `SpecialFeature` from JSON.
    /// - Parameter decoder: JSON Decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.featureType = try container.decode(String.self, forKey: .featureType)
        self.mediaSources = try container.decode([MediaSource].self, forKey: .mediaSources)
        self.imageBlurHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.imageTags = try container.decodeIfPresent(MediaImages.self, forKey: .imageTags)
    }

    /// Formats each feature's type for display (ex. "BehindTheScenes" -> "Behind The Scenes"), then groups the features by that type.
    /// - Parameter specialFeatures: Special features to group.
    /// - Returns: One array per feature type.
    public static func formatAndGroup(_ specialFeatures: [SpecialFeature]) -> [[any SpecialFeatureProtocol]] {
        let specialFeatures = specialFeatures.map { feature in
            if feature.featureType == "Unknown" { feature.featureType = "Extras" }
            else {
                feature.featureType =
                feature.featureType.pascalCaseToSpaces()
                if !feature.featureType.hasSuffix("s") && feature.featureType != "theme-music" { // Make plural
                    feature.featureType += "s"
                }
            }
            return feature
        }
        // Group by featureType
        return Dictionary(grouping: specialFeatures, by: \.featureType)
            .values
            .map { $0 as [any SpecialFeatureProtocol] }
    }
}

/// Quickly denotes the type of stream a stream is.
public enum StreamType: String, Decodable, Equatable {
    /// Denotes a visual stream.
    case video = "Video"
    /// Denotes an sonic stream.
    case audio = "Audio"
    /// Denotes a stream that visually describes the audio.
    case subtitle = "Subtitle"
    /// Unknown stream.
    case unknown
}

/// Holds information about all of a media's sources.
@Observable
public final class MediaSource: Decodable, MediaSourceProtocol {
    public var id: String
    public var name: String
    public var videoStreams: [any MediaStreamProtocol]
    public var audioStreams: [any MediaStreamProtocol]
    public var subtitleStreams: [any MediaStreamProtocol]
    public var startPoint: TimeInterval
    public var duration: TimeInterval

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case mediaStreams = "MediaStreams"
        case duration = "RunTimeTicks"
        case defaultAudioIndex = "DefaultAudioStreamIndex"
    }

    /// Create a `MediaSource` from JSON.
    /// Splits the server's single `MediaStreams` array into video, audio, and subtitle collections, and marks the server's default audio
    ///  stream so playback can start on the right track.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.startPoint = .zero

            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            let durationTicks = try container.decodeIfPresent(Int.self, forKey: .duration) ?? .zero
            self.duration = TimeInterval(ticks: durationTicks)

            let allStreams = try container.decodeIfPresent([MediaStream].self, forKey: .mediaStreams) ?? []

            videoStreams = allStreams.filter { $0.type == .video }
            let audioStreams = allStreams.filter { $0.type == .audio }
            subtitleStreams = allStreams.filter { $0.type == .subtitle }

            if let defaultAudioIndexInt = try container.decodeIfPresent(Int.self, forKey: .defaultAudioIndex) {
                let defaultAudioIndex = String(defaultAudioIndexInt)
                for i in audioStreams.indices {
                    if audioStreams[i].id == defaultAudioIndex { audioStreams[i].isDefault = true }
                    else { audioStreams[i].isDefault = false }
                }
            }
            self.audioStreams = audioStreams
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "MediaSource") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "MediaSource") }
            else { throw JSONError.failedJSONDecode("MediaSource", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("MediaSource", error) }
    }

    public static func == (lhs: MediaSource, rhs: MediaSource) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

/// Holds information about a particular media stream.
@Observable
public final class MediaStream: Decodable, Equatable, MediaStreamProtocol {
    public var id: String
    public var title: String
    public var type: StreamType
    public var bitrate: Int
    public var codec: String
    public var isDefault: Bool

    public enum CodingKeys: String, CodingKey {
        case id = "Index"
        case title = "DisplayTitle"
        case type = "Type"
        case bitrate = "BitRate"
        case codec = "Codec"
        case isDefault = "IsDefault"
    }

    /// Create a `MediaStream` from JSON.
    /// Bitrate is inflated for AV1, which the Apple TV cannot decode: the stream will be transcoded, so it needs a higher target bitrate
    /// to come out looking comparable.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let rawType = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
            type = StreamType(rawValue: rawType) ?? .unknown

            let intID = try container.decodeIfPresent(Int.self, forKey: .id) ?? Int.random(in: 0..<Int.max)
            id = String(intID)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown stream"
            codec = try container.decodeIfPresent(String.self, forKey: .codec) ?? ""
            isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
            bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate) ?? 10000
            if codec == "av1" {
                bitrate = Int(Double(bitrate) * 1.75) // AV1 isn't supported, but it's so good that we need way more bits
            }
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "MediaStream") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "MediaStream") }
            else { throw JSONError.failedJSONDecode("MediaStream", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("MediaStream", error) }
    }

    public static func == (lhs: MediaStream, rhs: MediaStream) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.type == rhs.type &&
        lhs.bitrate == rhs.bitrate &&
        lhs.codec == rhs.codec &&
        lhs.isDefault == rhs.isDefault
    }
}

/// Denotes the current status for downloading special features
public enum SpecialFeaturesStatus {
    /// Special features have not been fetched
    case unloaded
    /// Special features have been requested but have not yet returned
    case loading
    /// Special feature have been fully loaded
    case loaded([[any SpecialFeatureProtocol]])
}
