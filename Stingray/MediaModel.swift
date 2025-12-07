//
//  MediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

// MARK: Protocols
public protocol MediaProtocol: Identifiable {
    var title: String { get }
    var tagline: String { get }
    var description: String { get }
    var ImageTags: any MediaImagesProtocol { get }
    var id: String { get }
    var imageBlurHashes: (any MediaImageBlurHashesProtocol)? { get }
    var genres: [String] { get }
    var maturity: String? { get }
    var releaseDate: Date? { get }
    var mediaType: MediaType { get }
    var duration: Duration? { get }
    var people: [MediaPersonProtocol] { get }
}

public protocol MediaImagesProtocol {
    var thumbnail: String? { get }
    var logo: String? { get }
    var primary: String? { get }
}

public protocol MediaImageBlurHashesProtocol {
    var primary: [String: String]? { get }
    var thumb: [String: String]? { get }
    var logo: [String: String]? { get }
    var backdrop: [String: String]? { get }
    
    func getBlurHash(for key: MediaImageType) -> String?
}

public protocol MediaSourceProtocol: Identifiable {
    var id: String { get }
    var name: String { get }
    var videoStreams: [any MediaStreamProtocol] { get }
    var audioStreams: [any MediaStreamProtocol] { get }
    var subtitleStreams: [any MediaStreamProtocol] { get }
    var startTicks: Int { get set }
}

extension MediaSourceProtocol {
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
        return streams.first { $0.title == baseStream.title}
    }
}

public protocol MediaPersonProtocol {
    var id: String { get }
    var name: String { get }
    var role: String { get }
    var type: String { get }
    var image: String? { get }
    var imageHashes: MediaImageBlurHashes? { get }
}

public protocol MediaStreamProtocol: Identifiable {
    var id: Int { get }
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

public protocol TVEpisodeProtocol: Identifiable {
    var id: String { get }
    var blurHashes: MediaImageBlurHashes? { get }
    var title: String { get }
    var episodeNumber: Int { get }
    var mediaSources: [any MediaSourceProtocol] { get }
    var lastPlayed: Date? { get }
}

// MARK: Concrete types
public final class MediaModel: MediaProtocol, Decodable {
    public var title: String
    public var tagline: String
    public var description: String
    public var ImageTags: any MediaImagesProtocol
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
        self.ImageTags = try container.decodeIfPresent(MediaImages.self, forKey: .imageTags) ?? MediaImages(thumbnail: nil, logo: nil, primary: nil)
        
        // Decode blur hashes if present
        self.imageBlurHashes = try container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        
        self.id = try container.decode(String.self, forKey: .id)
        
        self.genres = try container.decode([String].self, forKey: .genres)
        
        self.maturity = try container.decodeIfPresent(String.self, forKey: .maturity)
        
        // Setup media type which will have different types of content within it (ex. movie or tv seasons)
        let mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        switch mediaType {
        case .movies(_):
            var movieSources = try container.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? []
            let userDataContainer = try container.decode(UserData.self, forKey: .userData)
            if let defaultIndex = movieSources.firstIndex(where: { $0.id == userDataContainer.mediaItemID}) {
                movieSources[defaultIndex].startTicks = userDataContainer.playbackPositionTicks
            }
            self.mediaType = .movies(movieSources)
        default:
            self.mediaType = mediaType
        }
        
        if let runtimeTicks = try container.decodeIfPresent(Int.self, forKey: .duration) {
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
}

public struct MediaImages: Decodable, Equatable, MediaImagesProtocol {
    public var thumbnail: String?
    public var logo: String?
    public var primary: String?
    
    enum CodingKeys: String, CodingKey {
        case thumbnail = "Thumb"
        case logo = "Logo"
        case primary = "Primary"
    }
}

public struct MediaImageBlurHashes: Decodable, Equatable, MediaImageBlurHashesProtocol {
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

public struct MediaSource: Decodable, Equatable, MediaSourceProtocol {
    public var id: String
    public var name: String
    public var videoStreams: [any MediaStreamProtocol]
    public var audioStreams: [any MediaStreamProtocol]
    public var subtitleStreams: [any MediaStreamProtocol]
    public var startTicks: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case mediaStreams = "MediaStreams"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        
        // Decode all media streams
        let allStreams = try container.decodeIfPresent([MediaStream].self, forKey: .mediaStreams) ?? []
        
        // Separate streams by type
        self.videoStreams = allStreams.filter { $0.type == .video }
        self.audioStreams = allStreams.filter { $0.type == .audio }
        self.subtitleStreams = allStreams.filter { $0.type == .subtitle }
        
        // Default values
        startTicks = 0
    }
    
    public static func == (lhs: MediaSource, rhs: MediaSource) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

public struct MediaStream: Decodable, Equatable, MediaStreamProtocol {
    public var id: Int
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawType = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.type = StreamType(rawValue: rawType) ?? .unknown
        
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? Int.random(in: 0..<Int.max)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown stream"
        self.codec = try container.decodeIfPresent(String.self, forKey: .codec) ?? ""
        self.bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate) ?? 10000
        if codec == "av1" {
            self.bitrate = Int(Double(self.bitrate) * 1.75) // AV1 isn't supported, but it's so good that we need way more bits
        }
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

public struct MediaPerson: MediaPersonProtocol, Identifiable, Decodable {
    public var id: String
    public var name: String
    public var role: String
    public var type: String
    public var image: String?
    public var imageHashes: MediaImageBlurHashes?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case type = "Type"
        case image = "PrimaryImageTag"
        case imageHashes = "ImageBlurHashes"
    }
}

public struct TVSeason: TVSeasonProtocol {
    public var id: String
    public var title: String
    public var episodes: [any TVEpisodeProtocol]
    public var seasonNumber: Int
}

public struct TVEpisode: TVEpisodeProtocol {
    public var id: String
    public var blurHashes: MediaImageBlurHashes?
    public var title: String
    public var episodeNumber: Int
    public var mediaSources: [any MediaSourceProtocol]
    public var lastPlayed: Date?
}

public enum StreamType: String, Decodable, Equatable {
    case video = "Video"
    case audio = "Audio"
    case subtitle = "Subtitle"
    case unknown
}
