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
    /// Short descriptor of the media.
    var tagline: String { get }
    /// Long descriptor of the media.
    var description: String { get }
    /// ID of the media given by the server.
    var id: String { get }
    /// List of genres that describe the media. Ex `["Action", "Adventure", "Drama"]`
    var genres: [String] { get }
    /// Rating of this media provided by the server. Ex PG, PG-13, R.
    var maturity: String? { get }
    /// Date the series first released. For shows with multiple episodes, this will be the date of the first episode.
    var releaseDate: Date? { get }
    /// Denotes TV show, vs movie, vs... and contains relevant data for that type.
    var mediaType: MediaType { get }
    /// Estimated runtime of the movie or per-episode.
    var duration: Duration? { get }
    /// People involved in the creation of this media.
    var people: [MediaPersonProtocol] { get }
    /// Tracks if the special features have been fetched. If they have been successfully fetched, they'll available through this variable.
    var specialFeatures: SpecialFeaturesStatus { get set }
    
    /// Load special features for this media
    func loadSpecialFeatures(specialFeatures: [SpecialFeature])
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

/// Special feature for a given media. Ex. BTS, extras, deleted scenes...
public protocol SpecialFeatureProtocol: Displayable {
    /// Feature type given by the server.
    var featureType: String { get }
    /// Data streams.
    var mediaSources: [any MediaSourceProtocol] { get }
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

/// Describes how to hold data about a person for a piece of media
public protocol MediaPersonProtocol {
    /// ID of the person
    var id: String { get }
    /// Person's full name
    var name: String { get }
    /// How they contributed to the media.
    var role: String { get }
    /// Preview hashes
    var imageHashes: MediaImageBlurHashes? { get }
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

/// Describes how to hold information about a TV Season
public protocol TVSeasonProtocol: Identifiable {
    /// A generic ID - Not relevant to the ID of the season set by the server.
    var id: String { get }
    /// Name of the season. Ex: "Special", "Season 2 Cont.", or "Season 1".
    var title: String { get }
    /// Episodes associated with this season.
    var episodes: [any TVEpisodeProtocol] { get set }
}

/// Describes how to hold information about a TV Episode.
public protocol TVEpisodeProtocol: Displayable {
    /// ID given by the server.
    var id: String { get }
    /// Name of the episode.
    var title: String { get }
    /// Episode number in a season.
    var episodeNumber: Int { get }
    /// Media streams for this episode.
    var mediaSources: [any MediaSourceProtocol] { get }
    /// Time it was last played. Nil if it was never played.
    var lastPlayed: Date? { get set }
    /// Longer description of the episode. Nil if none is provided.
    var overview: String? { get }
}

// MARK: Concrete types
/// Stores all high-level information about a piece of media.
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
                movieSources[defaultIndex].startPoint = TimeInterval(ticks: userDataContainer.playbackPositionTicks)
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
    
    /// Stores and formats the special features for this media.
    /// - Parameter specialFeatures: Special features to add.
    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) {
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
        let groupedFeatures = Dictionary(grouping: specialFeatures, by: \.featureType)
            .values
            .map { $0 as [any SpecialFeatureProtocol] }
        
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

/// Holds information about all of a media's sources.
@Observable
public final class MediaSource: Decodable, Equatable, MediaSourceProtocol {
    public var id: String
    public var name: String
    public var videoStreams: [any MediaStreamProtocol]
    public var audioStreams: [any MediaStreamProtocol]
    public var subtitleStreams: [any MediaStreamProtocol]
    public var startPoint: TimeInterval
    public var duration: TimeInterval
    
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

/// Holds information about a single person who worked on a piece of media.
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

/// Holds information about a particular TV Season.
@Observable
public final class TVSeason: TVSeasonProtocol {
    public var id: String
    public var title: String
    public var episodes: [any TVEpisodeProtocol]
    
    /// Create a TVSeason with defined episodes.
    /// - Parameters:
    ///   - title: Name of the season. Ex: "Special", "Season 2 Cont.", or "Season 1".
    ///   - episodes: Episodes associated with the season.
    public init(title: String, episodes: [any TVEpisodeProtocol]) {
        self.id = UUID().uuidString
        self.title = title
        self.episodes = episodes
    }
    
    /// Decodes an array of TV seasons from a JSON response containing episode data
    /// - Parameter decoder: The decoder to read data from
    /// - Returns: An array of TV seasons with episodes grouped appropriately
    /// - Throws: JSONError if decoding fails
    public static func decodeSeasons(from decoder: Decoder) throws(JSONError) -> [TVSeason] {
        enum CodingKeys: String, CodingKey {
            case items = "Items"
        }
        
        enum SeasonKeys: String, CodingKey {
            case title = "Name"
            case id = "Id"
            case episodeRuntimeTicks = "RunTimeTicks"
            case episodeNumber = "IndexNumber"
            case episodeOverview = "Overview"
            case seasonNumber = "ParentIndexNumber"
            case blurHashes = "ImageBlurHashes"
            case mediaSources = "MediaSources"
            case userData = "UserData"
            
            case seasonID = "SeasonId" // The actual season ID
            case seasonTitle = "SeasonName" // The actual season name
            case seriesID = "SeriesId" // Fallback for seasonID if SeasonId is missing
        }
        
        enum UserData: String, CodingKey {
            case lastPlayedDate = "LastPlayedDate"
            case playbackPosition = "PlaybackPositionTicks"
        }
        
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var seasonsContainer = try container.nestedUnkeyedContainer(forKey: .items)
            var tempSeasons: [TVSeason] = []
            var standInEpisodeNumber: Int = 0
            var lastSeasonID: String = ""
            
            while !seasonsContainer.isAtEnd {
                standInEpisodeNumber += 1 // Fallback episode number if it's not present
                let episodeContainer = try seasonsContainer.nestedContainer(keyedBy: SeasonKeys.self)
                let userDataContainer = try episodeContainer.nestedContainer(keyedBy: UserData.self, forKey: .userData)
                
                let episode: TVEpisode = TVEpisode(
                    id: try episodeContainer.decode(String.self, forKey: .id),
                    blurHashes: try episodeContainer.decodeIfPresent(MediaImageBlurHashes.self, forKey: .blurHashes),
                    title: try episodeContainer.decode(String.self, forKey: .title),
                    episodeNumber: try episodeContainer.decodeIfPresent(Int.self, forKey: .episodeNumber) ?? standInEpisodeNumber,
                    mediaSources: try episodeContainer.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? [],
                    lastPlayed: {
                        guard let dateString = try? userDataContainer.decodeIfPresent(
                            String.self,
                            forKey: .lastPlayedDate
                        ) else { return nil }
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter.date(from: dateString)
                    }(),
                    overview: try episodeContainer.decodeIfPresent(String.self, forKey: .episodeOverview)
                )
                let seasonID = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonID) ??
                episodeContainer.decode(String.self, forKey: .seriesID)
                
                if let playbackTicks = try userDataContainer.decodeIfPresent(Int.self, forKey: .playbackPosition) {
                    for mediaSourceIndex in episode.mediaSources.indices {
                        episode.mediaSources[mediaSourceIndex].startPoint = TimeInterval(ticks: playbackTicks)
                    }
                }
                
                let seasonTitle = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season"
                if seasonTitle == "Specials" { // Episode is a special
                    let newSeason = TVSeason(
                        title: "Special",
                        episodes: [episode]
                    )
                    tempSeasons.append(newSeason)
                }
                else if seasonID == lastSeasonID && tempSeasons.last?.title == "Special" { // Season was split by specials
                    lastSeasonID = seasonID
                    let newSeason = TVSeason(
                        title: (try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season") +
                        " Cont.",
                        episodes: [episode]
                    )
                    tempSeasons.append(newSeason)
                }
                else if seasonID == lastSeasonID, let lastSeason = tempSeasons.last { // Episode is in the last season
                    lastSeason.episodes.append(episode)
                }
                else { // Episode needs a new season
                    lastSeasonID = seasonID
                    let newSeason = TVSeason(
                        title: try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season",
                        episodes: [episode]
                    )
                    tempSeasons.append(newSeason)
                }
            }
            return tempSeasons
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "TVSeason.decodeSeasons") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "TVSeason.decodeSeasons") }
            else { throw JSONError.failedJSONDecode("Season Media", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("Season Media", error) }
    }
}

/// Holds information about a particular TV Episode.
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

/// Denotes the type of media a `MediaModel` is.
public enum MediaType: Decodable {
    /// Movies type with the associated media sources.
    case movies([any MediaSourceProtocol])
    /// TV type with the associated seasons.
    case tv([any TVSeasonProtocol]?)
    /// Unknown media type
    case unknown
    
    /// Create a media type that does not populate its data. Ex. Creates a movie media type with no media sources attached.
    /// - Parameter decoder: JSON decoder.
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

/// Holds a singular special feature's information.
public final class SpecialFeature: SpecialFeatureProtocol, Decodable {
    public let id: String
    public var featureType: String
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
}
