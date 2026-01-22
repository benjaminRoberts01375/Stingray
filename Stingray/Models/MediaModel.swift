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
    var imageTags: any MediaImagesProtocol { get }
    var id: String { get }
    var genres: [String] { get }
    var maturity: String? { get }
    var releaseDate: Date? { get }
    var mediaType: MediaType { get }
    var duration: Duration? { get }
    var people: [MediaPersonProtocol] { get }
}

public protocol SlimMediaProtocol: Identifiable, Hashable {
    var id: String { get }
    var title: String { get }
    var imageTags: any MediaImagesProtocol { get }
    var imageBlurHashes: (any MediaImageBlurHashesProtocol)? { get }
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

/// Track image hashes for displaying previews
public protocol MediaImageBlurHashesProtocol {
    /// Primary hashes
    var primary: [String: String]? { get }
    /// Thumbnail hashes
    var thumb: [String: String]? { get }
    /// Logo hashes
    var logo: [String: String]? { get }
    /// Backdrop hashes
    var backdrop: [String: String]? { get }
    
    /// Request a type of blur hash
    func getBlurHash(for key: MediaImageType) -> String?
}

public enum MediaImageType: String {
    case thumbnail = "Thumb"
    case logo = "Logo"
    case primary = "Primary"
    case backdrop = "Backdrop"
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
    
    /// Returns the best (highest quality) video range type from this media source's video streams
    var bestVideoRangeType: VideoRangeType {
        // Priority: Dolby Vision > HDR10+ > HDR10 > HLG > SDR
        let rangeTypes = videoStreams.map { $0.videoRangeType }
        
        if rangeTypes.contains(where: { $0.isDolbyVision }) {
            return rangeTypes.first { $0.isDolbyVision } ?? .sdr
        }
        if rangeTypes.contains(.hdr10Plus) { return .hdr10Plus }
        if rangeTypes.contains(.hdr10) { return .hdr10 }
        if rangeTypes.contains(.hlg) { return .hlg }
        return .sdr
    }
    
    /// Whether this media source has any HDR content
    var hasHDR: Bool {
        videoStreams.contains { $0.videoRangeType.isHDR }
    }
    
    /// Whether this media source has Dolby Vision content
    var hasDolbyVision: Bool {
        videoStreams.contains { $0.videoRangeType.isDolbyVision }
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
    /// Type of contribution. Ex. Director
    var type: String { get }
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
    /// The video range type (SDR, HDR10, Dolby Vision, etc.)
    var videoRangeType: VideoRangeType { get }
}

/// Represents the dynamic range type of a video stream
public enum VideoRangeType: String, Decodable, Equatable {
    case sdr = "SDR"
    case hdr10 = "HDR10"
    case hdr10Plus = "HDR10Plus"
    case hlg = "HLG"
    case dolbyVision = "DOVI"
    case dolbyVisionWithHDR10 = "DOVIWithHDR10"
    case dolbyVisionWithHLG = "DOVIWithHLG"
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = VideoRangeType(rawValue: rawValue) ?? .unknown
    }
    
    /// Whether this is any form of HDR content
    public var isHDR: Bool {
        self != .sdr && self != .unknown
    }
    
    /// Whether this is Dolby Vision content
    public var isDolbyVision: Bool {
        switch self {
        case .dolbyVision, .dolbyVisionWithHDR10, .dolbyVisionWithHLG:
            return true
        default:
            return false
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .sdr: return "SDR"
        case .hdr10: return "HDR10"
        case .hdr10Plus: return "HDR10+"
        case .hlg: return "HLG"
        case .dolbyVision: return "Dolby Vision"
        case .dolbyVisionWithHDR10: return "Dolby Vision"
        case .dolbyVisionWithHLG: return "Dolby Vision"
        case .unknown: return "Unknown"
        }
    }
}

public protocol TVSeasonProtocol: Identifiable {
    var id: String { get }
    var title: String { get }
    var episodes: [any TVEpisodeProtocol] { get }
    var seasonNumber: Int { get }
}

public protocol TVEpisodeProtocol: Identifiable {
    var id: String { get }
    var blurHashes: MediaImageBlurHashes? { get }
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
    public var imageTags: any MediaImagesProtocol
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var mediaType: MediaType
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        self.title = title
        
        // Taglines might not always be present, so decode as optional
        let taglines = try container.decodeIfPresent([String].self, forKey: .taglines)
        self.tagline = taglines?.first ?? ""
        
        // Overview might also be optional
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        
        // ImageTags might be optional as well
        self.imageTags = try container.decodeIfPresent(MediaImages.self, forKey: .imageTags) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        
        // Decode blur hashes if present
        self.imageBlurHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        
        self.id = try container.decode(String.self, forKey: .id)
        
        self.genres = try container.decode([String].self, forKey: .genres)
        
        self.maturity = try container.decodeIfPresent(String.self, forKey: .maturity)
        
        // Setup media type which will have different types of content within it (ex. movie or tv seasons)
        let mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        switch mediaType {
        case .movies:
            let movieSources = try container.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? []
            let userDataContainer = try container.decode(UserData.self, forKey: .userData)
            if let defaultIndex = movieSources.firstIndex(where: { $0.id == userDataContainer.mediaItemID }) {
                movieSources[defaultIndex].startTicks = userDataContainer.playbackPositionTicks
            }
            self.mediaType = .movies(movieSources)
        default:
            self.mediaType = mediaType
        }
        
        if let runtimeTicks = try container.decodeIfPresent(Int.self, forKey: .duration), runtimeTicks != 0 {
            self.duration = .nanoseconds(100 * runtimeTicks)
        }
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .releaseDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.releaseDate = formatter.date(from: dateString)
        } else {
            self.releaseDate = nil
        }
        
        self.people = try container.decodeIfPresent([MediaPerson].self, forKey: .people) ?? []
        
        // Get current progress if it exists
        struct UserData: Decodable {
            let playbackPositionTicks: Int
            let mediaItemID: String
            
            enum CodingKeys: String, CodingKey {
                case playbackPositionTicks = "PlaybackPositionTicks"
                case mediaItemID = "ItemId"
            }
        }
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
public final class SlimMedia: SlimMediaProtocol, Decodable {
    public var id: String
    public var title: String
    public var imageTags: any MediaImagesProtocol
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var parentID: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case seriesID = "SeriesId"
        case seriesTitle = "SeriesName"
        case title = "Name"
        case imageBlurHashes = "ImageBlurHashes"
        case imageTags = "ImageTags"
        case parentID = "ParentId"
        case parentPrimaryImage = "SeriesPrimaryImageTag"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imageBlurHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        
        self.id = try container.decodeIfPresent(String.self, forKey: .seriesID) ??
        container.decode(String.self, forKey: .id)
        
        self.title = try container.decodeIfPresent(String.self, forKey: .seriesTitle) ??
        container.decode(String.self, forKey: .title)
        
        self.imageTags = try container.decodeIfPresent(MediaImages.self, forKey: .imageTags) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
    }
    
    // Hashable conformance
    public static func == (lhs: SlimMedia, rhs: SlimMedia) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
public final class MediaImages: Decodable, Equatable, MediaImagesProtocol {
    public static func == (lhs: MediaImages, rhs: MediaImages) -> Bool {
        lhs.thumbnail == rhs.thumbnail &&
        lhs.logo == rhs.logo &&
        lhs.primary == rhs.primary
    }
    
    public var thumbnail: String?
    public var logo: String?
    public var primary: String?
    
    enum CodingKeys: String, CodingKey {
        case thumbnail = "Thumb"
        case logo = "Logo"
        case primary = "Primary"
    }
    
    public init(thumbnail: String?, logo: String?, primary: String?) {
        self.thumbnail = thumbnail
        self.logo = logo
        self.primary = primary
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.logo = try container.decodeIfPresent(String.self, forKey: .logo)
        self.primary = try container.decodeIfPresent(String.self, forKey: .primary)
    }
}

@Observable
public final class MediaImageBlurHashes: Decodable, Equatable, MediaImageBlurHashesProtocol {
    public var primary: [String: String]?
    public var thumb: [String: String]?
    public var logo: [String: String]?
    public var backdrop: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case thumb = "Thumb"
        case logo = "Logo"
        case backdrop = "Backdrop"
    }
    
    public static func == (lhs: MediaImageBlurHashes, rhs: MediaImageBlurHashes) -> Bool {
        lhs.primary == rhs.primary &&
        lhs.thumb == rhs.thumb &&
        lhs.logo == rhs.logo &&
        lhs.backdrop == rhs.backdrop
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primary = try container.decodeIfPresent([String: String].self, forKey: .primary)
        self.thumb = try container.decodeIfPresent([String: String].self, forKey: .thumb)
        self.logo = try container.decodeIfPresent([String: String].self, forKey: .logo)
        self.backdrop = try container.decodeIfPresent([String: String].self, forKey: .backdrop)
    }
    
    public func getBlurHash(for key: MediaImageType) -> String? {
        switch key {
        case .primary:
            return primary?.values.first
        case .thumbnail:
            return thumb?.values.first
        case .logo:
            return logo?.values.first
        case .backdrop:
            return backdrop?.values.first
        }
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.durationTicks = try container.decodeIfPresent(Int.self, forKey: .duration)
        
        // Decode all media streams
        let allStreams = try container.decodeIfPresent([MediaStream].self, forKey: .mediaStreams) ?? []
        
        // Separate streams by type
        self.videoStreams = allStreams.filter { $0.type == .video }
        let audioStreams = allStreams.filter { $0.type == .audio }
        self.subtitleStreams = allStreams.filter { $0.type == .subtitle }
        
        if let defaultAudioIndexInt = try container.decodeIfPresent(Int.self, forKey: .defaultAudioIndex) {
            let defaultAudioIndex = String(defaultAudioIndexInt)
            for i in audioStreams.indices {
                if audioStreams[i].id == defaultAudioIndex { audioStreams[i].isDefault = true }
                else { audioStreams[i].isDefault = false }
            }
        }
        self.audioStreams = audioStreams
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
    public var videoRangeType: VideoRangeType
    /// Color space (e.g., bt709, bt2020)
    public var colorSpace: String?
    /// Color transfer function (e.g., sdr, pq, hlg)
    public var colorTransfer: String?
    /// Color primaries (e.g., bt709, bt2020)
    public var colorPrimaries: String?
    /// Dolby Vision profile number (5, 7, 8, etc.)
    public var dolbyVisionProfile: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "Index"
        case title = "DisplayTitle"
        case type = "Type"
        case bitrate = "BitRate"
        case codec = "Codec"
        case isDefault = "IsDefault"
        case videoRangeType = "VideoRangeType"
        case colorSpace = "ColorSpace"
        case colorTransfer = "ColorTransfer"
        case colorPrimaries = "ColorPrimaries"
        case videoDoViTitle = "VideoDoViTitle"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawType = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.type = StreamType(rawValue: rawType) ?? .unknown
        
        let intID = try container.decodeIfPresent(Int.self, forKey: .id) ?? Int.random(in: 0..<Int.max)
        self.id = String(intID)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown stream"
        self.codec = try container.decodeIfPresent(String.self, forKey: .codec) ?? ""
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate) ?? 10000
        if codec == "av1" {
            self.bitrate = Int(Double(self.bitrate) * 1.75) // AV1 isn't supported, but it's so good that we need way more bits
        }
        
        // HDR metadata
        self.videoRangeType = try container.decodeIfPresent(VideoRangeType.self, forKey: .videoRangeType) ?? .sdr
        self.colorSpace = try container.decodeIfPresent(String.self, forKey: .colorSpace)
        self.colorTransfer = try container.decodeIfPresent(String.self, forKey: .colorTransfer)
        self.colorPrimaries = try container.decodeIfPresent(String.self, forKey: .colorPrimaries)
        
        // Parse Dolby Vision profile from the title if present (e.g., "Dolby Vision Profile 8")
        if let doViTitle = try container.decodeIfPresent(String.self, forKey: .videoDoViTitle) {
            let pattern = /Profile (\d+)/
            if let match = doViTitle.firstMatch(of: pattern) {
                self.dolbyVisionProfile = Int(match.1)
            }
        }
    }
    
    public static func == (lhs: MediaStream, rhs: MediaStream) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.type == rhs.type &&
        lhs.bitrate == rhs.bitrate &&
        lhs.codec == rhs.codec &&
        lhs.isDefault == rhs.isDefault &&
        lhs.videoRangeType == rhs.videoRangeType
    }
}

@Observable
public final class MediaPerson: MediaPersonProtocol, Identifiable, Decodable {
    public var id: String
    public var name: String
    public var role: String
    public var type: String
    public var imageHashes: MediaImageBlurHashes?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case type = "Type"
        case imageHashes = "ImageBlurHashes"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.role = try container.decode(String.self, forKey: .role)
        self.type = try container.decode(String.self, forKey: .type)
        self.imageHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageHashes)
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
    public var id: String
    public var blurHashes: MediaImageBlurHashes?
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
        self.blurHashes = blurHashes
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
    case collections
    case movies([any MediaSourceProtocol])
    case tv([TVSeason]?)
    
    public init (from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        
        switch stringValue {
        case MediaType.collections.rawValue:
            self = .collections
        case "Movie":
            self = .movies([])
        case "Series":
            self = .tv(nil)
        default:
            throw InitError.unknownType(stringValue)
        }
    }
    
    /// Errors pertaining to failed setup
    public enum InitError: Error {
        /// The media type is unknown.
        case unknownType(String)
        
        var description: String {
            switch self {
            case .unknownType(let badType):
                "Unknown media type: \(badType)"
            }
        }
    }
    
    var rawValue: String {
        switch self {
        case .collections:
            return "BoxSet"
        case .movies:
            return "Movie"
        case .tv:
            return "Series"
        }
    }
    
    /// Returns all media sources from this media type
    var mediaSources: [any MediaSourceProtocol] {
        switch self {
        case .collections:
            return []
        case .movies(let sources):
            return sources
        case .tv(let seasons):
            guard let seasons else { return [] }
            return seasons.flatMap { $0.episodes.flatMap { $0.mediaSources } }
        }
    }
}

// MARK: - HDR Helpers for MediaProtocol

extension MediaProtocol {
    /// Returns the best video range type across all media sources
    var bestVideoRangeType: VideoRangeType {
        let sources = mediaType.mediaSources
        guard !sources.isEmpty else { return .sdr }
        
        // Check for Dolby Vision first (highest priority)
        if sources.contains(where: { $0.hasDolbyVision }) {
            return sources.first { $0.hasDolbyVision }?.bestVideoRangeType ?? .dolbyVision
        }
        
        // Then check for any HDR
        if let hdrSource = sources.first(where: { $0.hasHDR }) {
            return hdrSource.bestVideoRangeType
        }
        
        return .sdr
    }
    
    /// Whether this media has any HDR content
    var hasHDR: Bool {
        mediaType.mediaSources.contains { $0.hasHDR }
    }
    
    /// Whether this media has Dolby Vision content
    var hasDolbyVision: Bool {
        mediaType.mediaSources.contains { $0.hasDolbyVision }
    }
}
