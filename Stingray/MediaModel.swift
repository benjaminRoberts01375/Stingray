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
    var mediaSources: [any MediaSourceProtocol] { get }
    var imageBlurHashes: (any MediaImageBlurHashesProtocol)? { get }
    var genres: [String] { get }
    var maturity: String? { get }
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
}

public protocol MediaStreamProtocol: Identifiable {
    var id: Int { get }
    var title: String? { get }
    var displayTitle: String { get }
    var type: StreamType { get }
    var bitrate: Int? { get }
}

// MARK: Concrete types
public final class MediaModel: MediaProtocol, Decodable {
    public var title: String
    public var tagline: String
    public var description: String
    public var ImageTags: any MediaImagesProtocol
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var mediaSources: [any MediaSourceProtocol]
    public var genres: [String]
    public var maturity: String?
    
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
        
        // Decode media sources - may not exist for all items
        self.mediaSources = try container.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? []
        
        self.genres = try container.decode([String].self, forKey: .genres)
        
        self.maturity = try container.decodeIfPresent(String.self, forKey: .maturity)
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
    }
    
    public static func == (lhs: MediaSource, rhs: MediaSource) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

public struct MediaStream: Decodable, Equatable, MediaStreamProtocol {
    public var id: Int
    public var title: String?
    public var displayTitle: String
    public var type: StreamType
    public var bitrate: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "Index"
        case title = "Title"
        case displayTitle = "DisplayTitle"
        case type = "Type"
        case bitrate = "BitRate"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.displayTitle = try container.decode(String.self, forKey: .displayTitle)
        self.type = try container.decode(StreamType.self, forKey: .type)
        self.bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate)
    }
}

public enum StreamType: String, Decodable, Equatable {
    case video = "Video"
    case audio = "Audio"
    case subtitle = "Subtitle"
}
