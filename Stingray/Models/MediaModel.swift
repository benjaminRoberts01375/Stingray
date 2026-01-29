//
//  MediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

// MARK: Protocols

/// Define the shape of a piece of media
public protocol MediaProtocol: Identifiable, SlimMediaProtocol, Hashable {
    var tagline: String { get }
    var description: String { get }
    var id: String { get }
    var genres: [String] { get }
    var maturity: String? { get }
    var releaseDate: Date? { get }
    var mediaType: MediaType { get }
    var duration: Duration? { get }
    var people: [MediaPersonProtocol] { get }
    var specialFeatures: SpecialFeaturesStatus { get set }
    
    /// Load special features for this media
    func loadSpecialFeatures(specialFeatures: [SpecialFeature])
}

public protocol MediaSourceProtocol: Identifiable {
    var id: String { get }
    var name: String { get }
    var videoStreams: [any MediaStreamProtocol] { get }
    var audioStreams: [any MediaStreamProtocol] { get }
    var subtitleStreams: [any MediaStreamProtocol] { get }
    var startTicks: Int { get set }
    var durationTicks: Int? { get }
}

public protocol SpecialFeaturesProtocol: Displayable {
    var featureType: String { get }
    var sortTitle: String? { get }
    var title: String { get }
    var mediaSources: [any MediaSourceProtocol] { get }
}

/// Denotes the current status for downloading special features
public enum SpecialFeaturesStatus {
    /// Special features have not been fetched
    case unloaded
    /// Special features have been requested but have not yet returned
    case loading
    /// Special feature have been fully loaded
    case loaded([[any SpecialFeaturesProtocol]])
}

/// Extend the MediaSourceProtocol to allow for getting similar streams
extension MediaSourceProtocol {
    /// Gets a streams based on stream type and title. This is good for having an existing stream for an episode, and finding a similar one
    /// for the next episode.
    /// - Parameters:
    ///   - baseStream: Initial stream to pull metadata from.
    ///   - streamType: Desired type of stream.
    /// - Returns: A potential matching stream.
    func getSimilarStream(baseStream: any MediaStreamProtocol, streamType: StreamType) -> (any MediaStreamProtocol)? {
        var streams: [any MediaStreamProtocol]
        switch streamType {
        case .video:
            streams = videoStreams
        case .audio:
            streams = audioStreams
        case .subtitle:
            streams = subtitleStreams
        case .unknown:
            return nil
        }
        return streams.first { $0.title == baseStream.title }
    }
}

/// Data about a person for a piece of media
public protocol MediaPersonProtocol {
    /// ID of the person
    var id: String { get }
    /// Person's firstname and lastname
    var name: String { get }
    /// How they contributed to the media
    var role: String { get }
    /// Preview hashes
    var imageHashes: MediaImageBlurHashes? { get }
}

public protocol MediaStreamProtocol: Identifiable {
    var id: String { get }
    var title: String { get }
    var type: StreamType { get }
    var bitrate: Int { get }
    var codec: String { get }
    var isDefault: Bool { get }
}

public protocol TVSeasonProtocol: Identifiable {
    var id: String { get }
    var title: String { get }
    var episodes: [any TVEpisodeProtocol] { get }
    var seasonNumber: Int { get }
}

public protocol TVEpisodeProtocol: Displayable {
    var id: String { get }
    var title: String { get }
    var episodeNumber: Int { get }
    var mediaSources: [any MediaSourceProtocol] { get }
    var lastPlayed: Date? { get }
    var overview: String? { get }
}

// MARK: Concrete types
@Observable
public final class MediaModel: MediaProtocol, Decodable {
    public var title: String
    public var tagline: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var mediaType: MediaType
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    public var errors: [RError]?
    public var specialFeatures: SpecialFeaturesStatus
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case mediaSources = "MediaSources"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case mediaType = "Type"
        case duration = "RunTimeTicks"
        case people = "People"
        case userData = "UserData"
    }
    
    /// Sets up a Media Model from JSON
    /// - Parameter decoder: JSON decoder
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.specialFeatures = .unloaded
        
        var errBucket: [any RError] = []
        id = container.decodeFieldSafely(
            String.self,
            forKey: .id,
            default: UUID().uuidString,
            errBucket: &errBucket,
            errLabel: "Media Model"
        )
        
        title = container.decodeFieldSafely(
            String.self,
            forKey: .title,
            default: "Unknown Title",
            errBucket: &errBucket,
            errLabel: "Media Model"
        )
        
        let taglines = container.decodeFieldSafely(
            [String].self,
            forKey: .taglines,
            default: [],
            errBucket: &errBucket,
            errLabel: "Media Model"
        )
        tagline = taglines.first ?? ""
        
        description = container.decodeFieldSafely(
            String.self,
            forKey: .description,
            default: "",
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        imageTags = container.decodeFieldSafely(
            MediaImages.self,
            forKey: .imageTags,
            default: MediaImages(thumbnail: nil, logo: nil, primary: nil),
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        imageBlurHashes = container.decodeFieldSafely(
            MediaImageBlurHashes?.self,
            forKey: .imageBlurHashes,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        genres = container.decodeFieldSafely(
            [String].self,
            forKey: .genres,
            default: [],
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        maturity = container.decodeFieldSafely(
            String?.self,
            forKey: .maturity,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        let mediaType = container.decodeFieldSafely(
            MediaType.self,
            forKey: .mediaType,
            default: .unknown,
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        switch mediaType {
        case .movies:
            let movieSources = container.decodeFieldSafely(
                [MediaSource].self,
                forKey: .mediaSources,
                default: [],
                errBucket: &errBucket,
                errLabel: "Media Model"
            )
            
            struct UserData: Decodable {
                let playbackPositionTicks: Int
                let mediaItemID: String
                
                enum CodingKeys: String, CodingKey {
                    case playbackPositionTicks = "PlaybackPositionTicks"
                    case mediaItemID = "ItemId"
                }
            }
            
            let userDataContainer = container.decodeFieldSafely(
                UserData.self,
                forKey: .userData,
                default: UserData(playbackPositionTicks: .zero, mediaItemID: UUID().uuidString),
                errBucket: &errBucket,
                errLabel: "Media Model",
                required: false
            )
            if let defaultIndex = movieSources.firstIndex(where: { $0.id == userDataContainer.mediaItemID }) {
                movieSources[defaultIndex].startTicks = userDataContainer.playbackPositionTicks
            }
            self.mediaType = .movies(movieSources)
        default:
            self.mediaType = mediaType
        }
        
        let runtimeTicks = container.decodeFieldSafely(
            Int?.self,
            forKey: .duration,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        if let runtimeTicks = runtimeTicks, runtimeTicks != 0 { duration = .nanoseconds(100 * runtimeTicks) }
        else { duration = nil }
        
        if let dateString = container.decodeFieldSafely(
            String?.self,
            forKey: .releaseDate,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        ) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            releaseDate = formatter.date(from: dateString)
        } else { releaseDate = nil }
        
        people = container.decodeFieldSafely(
            [MediaPerson].self,
            forKey: .people,
            default: [],
            errBucket: &errBucket,
            errLabel: "Media Model",
            required: false
        )
        
        if !errBucket.isEmpty { errors = errBucket } // Otherwise nil
    }
    
    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) {
        let specialFeatures = specialFeatures.map { feature in
            if feature.featureType == "Unknown" { feature.featureType = "Extras" }
            else { feature.featureType = feature.featureType.pascalCaseToSpaces() }
            return feature
        }
        // Group by featureType
        let groupedFeatures = Dictionary(grouping: specialFeatures, by: \.featureType)
            .values
            .map { $0 as [any SpecialFeaturesProtocol] }
        
        self.specialFeatures = .loaded(groupedFeatures)
    }
    
    // Hashable conformance
    public static func == (lhs: MediaModel, rhs: MediaModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
public final class MediaSource: Decodable, Equatable, MediaSourceProtocol {
    public var id: String
    public var name: String
    public var videoStreams: [any MediaStreamProtocol]
    public var audioStreams: [any MediaStreamProtocol]
    public var subtitleStreams: [any MediaStreamProtocol]
    private var loadingStartTicks: Int?
    public var startTicks: Int {
        get { return loadingStartTicks ?? 0 }
        set { self.loadingStartTicks = newValue }
    }
    public var durationTicks: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case mediaStreams = "MediaStreams"
        case duration = "RunTimeTicks"
        case defaultAudioIndex = "DefaultAudioStreamIndex"
    }
    
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            durationTicks = try container.decodeIfPresent(Int.self, forKey: .duration)
            
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

@Observable
public final class MediaStream: Decodable, Equatable, MediaStreamProtocol {
    public var id: String
    public var title: String
    public var type: StreamType
    public var bitrate: Int
    public var codec: String
    public var isDefault: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "Index"
        case title = "DisplayTitle"
        case type = "Type"
        case bitrate = "BitRate"
        case codec = "Codec"
        case isDefault = "IsDefault"
    }
    
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

@Observable
public final class MediaPerson: MediaPersonProtocol, Identifiable, Decodable {
    public var id: String
    public var name: String
    public var role: String
    public var imageHashes: MediaImageBlurHashes?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case imageHashes = "ImageBlurHashes"
    }
    
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Anonymous"
            role = try container.decodeIfPresent(String.self, forKey: .role) ?? "Unknown Roll"
            imageHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageHashes)
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "MediaPerson") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "MediaPerson") }
            else { throw JSONError.failedJSONDecode("MediaPerson", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("MediaPerson", error) }
    }
}

@Observable
public final class TVSeason: TVSeasonProtocol {
    public var id: String
    public var title: String
    public var episodes: [any TVEpisodeProtocol]
    public var seasonNumber: Int
    
    public init(id: String, title: String, episodes: [any TVEpisodeProtocol], seasonNumber: Int) {
        self.id = id
        self.title = title
        self.episodes = episodes
        self.seasonNumber = seasonNumber
    }
}

@Observable
public final class TVEpisode: TVEpisodeProtocol {
    public var imageTags: (any MediaImagesProtocol)?
    public var id: String
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var title: String
    public var episodeNumber: Int
    public var mediaSources: [any MediaSourceProtocol]
    public var lastPlayed: Date?
    public var overview: String?
    
    init(
        id: String,
        blurHashes: MediaImageBlurHashes? = nil,
        title: String,
        episodeNumber: Int,
        mediaSources: [any MediaSourceProtocol],
        lastPlayed: Date? = nil,
        overview: String? = nil
    ) {
        self.id = id
        self.imageBlurHashes = blurHashes
        self.title = title
        self.episodeNumber = episodeNumber
        self.mediaSources = mediaSources
        self.lastPlayed = lastPlayed
        self.overview = overview
    }
}

public enum StreamType: String, Decodable, Equatable {
    case video = "Video"
    case audio = "Audio"
    case subtitle = "Subtitle"
    case unknown
}

public enum MediaType: Decodable {
    case movies([any MediaSourceProtocol])
    case tv([TVSeason]?)
    case unknown
    
    public init (from decoder: Decoder) throws(JSONError) {
        let container: any SingleValueDecodingContainer
        let stringValue: String
        
        do {
            container = try decoder.singleValueContainer()
            stringValue = try container.decode(String.self)
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "Media Image Blur Hash") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "Media Image Blur Hash") }
            else { throw JSONError.failedJSONDecode("Media Image Blur Hash", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("Media Image Blur Hash", error) }
        
        switch stringValue {
        case "Movie":
            self = .movies([])
        case "Series":
            self = .tv(nil)
        default:
            throw JSONError.unexpectedKey(MediaError.unknownMediaType(stringValue))
        }
    }
    
    var rawValue: String {
        switch self {
        case .movies:
            return "Movie"
        case .tv:
            return "Series"
        case .unknown:
            return "Unknown"
        }
    }
}

public final class SpecialFeature: SpecialFeaturesProtocol, Decodable {
    public let id: String
    public var featureType: String
    public let sortTitle: String?
    public let title: String
    public let mediaSources: [any MediaSourceProtocol]
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var imageTags: (any MediaImagesProtocol)?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case featureType = "ExtraType"
        case sortTitle = "SortName"
        case mediaSources = "MediaSources"
        case imageBlurHashes = "ImageBlurHashes"
        case imageTags = "ImageTags"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.featureType = try container.decode(String.self, forKey: .featureType)
        self.sortTitle = try container.decodeIfPresent(String.self, forKey: .sortTitle)
        self.title = try container.decode(String.self, forKey: .title)
        self.mediaSources = try container.decode([MediaSource].self, forKey: .mediaSources)
        self.imageBlurHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.imageTags = try container.decodeIfPresent(MediaImages.self, forKey: .imageTags)
    }
}
