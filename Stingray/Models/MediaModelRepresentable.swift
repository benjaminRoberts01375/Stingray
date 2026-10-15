//
//  MediaModelRepresentable.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// A slimmed down version of the `MediaProtocol` for faster loading.
public protocol MediaRepresentableProtocol: Displayable, MediaMetadataProtocol, Hashable {
    /// ID provided by the server.
    var id: String { get }
    /// Name of this media.
    var title: String { get }
}

/// The slimmest possible MediaModel for faster loading.
@Observable
public final class MediaModelRepresentable: MediaRepresentableProtocol, Decodable {
    public var title: String
    public var sortTitle: String
    public var tagline: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    /// A useful ID for linking this object with the full-sized `MediaModel` object.
    public let parentID: String?

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case parentID = "ParentId"
        case seriesID = "SeriesId"
        case seriesTitle = "SeriesName"
        case title = "Name"
        case sortTitle = "SortName"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case duration = "RunTimeTicks"
        case people = "People"
        case userData = "UserData"
    }
    
    /// Create a `MediaModelRepresentable` from JSON.
    /// - Parameter decoder: JSON Decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Prefer the series identity when present (e.g. NextUp returns episodes, but we
        // want the containing show). Fallback to the actual ID
        self.id = (try? container.decodeIfPresent(String.self, forKey: .seriesID)) ?? (
            (try? container.decodeIfPresent(String.self, forKey: .id)) ??
            UUID().uuidString
        )
        
        self.parentID = try? container.decodeIfPresent(String.self, forKey: .parentID)
        
        let title = (try? container.decodeIfPresent(String.self, forKey: .seriesTitle)) ?? (
            (try? container.decodeIfPresent(String.self, forKey: .title))
            ?? "Unknown Title"
        )
        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.tagline = (try? container.decodeIfPresent(String.self, forKey: .taglines)) ?? ""
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.imageTags = try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.maturity = (try? container.decodeIfPresent(String.self, forKey: .maturity)) ?? ""
        self.releaseDate = try? container.decodeIfPresent(Date.self, forKey: .releaseDate)
        if let runtimeTicks = try? container.decodeIfPresent(Int.self, forKey: .duration), runtimeTicks != 0 {
            self.duration = .nanoseconds(100 * runtimeTicks)
        }
        self.people = (try? container.decodeIfPresent([MediaPerson].self, forKey: .people)) ?? []
    }
    
    // Hashable conformance
    public static func == (lhs: MediaModelRepresentable, rhs: MediaModelRepresentable) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Some media designed to be displayed as an example
public final class ExampleMedia: MediaRepresentableProtocol {
    public let sortTitle: String
    public let tagline: String
    public let maturity: String?
    public let releaseDate: Date?
    public let genres: [String]
    public let duration: Duration?
    public let description: String
    public let people: [any MediaPersonProtocol]
    public let id: String
    public let title: String
    public let imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public let imageTags: (any MediaImagesProtocol)?
    
    public static func == (lhs: ExampleMedia, rhs: ExampleMedia) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    /// Creates example media with fixed placeholder metadata, used by the theme previews.
    /// - Parameter title: Title to display
    public init(title: String) {
        self.title = title
        self.sortTitle = title
        self.tagline = "A short tagline"
        self.maturity = "NA"
        self.releaseDate = Date.now
        self.genres = ["Drama", "Fantasy"]
        self.duration = .seconds(90 * 60) // 90 minutes
        self.description = "A wonderful story"
        self.people = []
        self.id = UUID().uuidString
        self.imageBlurHashes = nil
        self.imageTags = MediaImages(thumbnail: "Example", logo: "Example", primary: "Example")
    }
}
