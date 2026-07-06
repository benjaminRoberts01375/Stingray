//
//  MediaModelRepresentable.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// A slimmed down version of the `MediaModelProtocol` for faster loading.
public protocol MediaRepresentableProtocol: Displayable, MediaMetadataProtocol, Hashable {
    /// ID provided by the server.
    var id: String { get }
    /// Name of this media.
    var title: String { get }
}

/// A simple protocol that ensures content has the expected image data.
public protocol Displayable: Identifiable {
    /// Set of strings to make a crude image with.
    var imageBlurHashes: (any MediaImageBlurHashesProtocol)? { get }
    /// Set of strings to request fully detailed images with.
    var imageTags: (any MediaImagesProtocol)? { get }
    /// ID provided by the server.
    var id: String { get }
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
    var primary: String? { get }
    /// Logo hashes
    var logo: String? { get }
    /// Backdrop hashes
    var backdrop: String? { get }
}

public protocol MediaMetadataProtocol: Identifiable {
    /// Unique identifier for this media
    var id: String { get }
    /// The name of the series
    var title: String { get }
    /// Short descriptor of the media.
    var tagline: String { get }
    /// Rating of this media provided by the server. Ex PG, PG-13, R.
    var maturity: String? { get }
    /// Date the series first released. For shows with multiple episodes, this will be the date of the first episode.
    var releaseDate: Date? { get }
    /// List of genres that describe the media. Ex `["Action", "Adventure", "Drama"]`
    var genres: [String] { get }
    /// Estimated runtime of the movie or per-episode.
    var duration: Duration? { get }
    /// A longer descriptor of the series
    var description: String { get }
    /// Those involved with the media in its entirety
    var people: [any MediaPersonProtocol] { get }
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

/// The slimmest possible MediaModel for faster loading.
@Observable
public final class MediaModelRepresentable: MediaRepresentableProtocol, Decodable {
    public var title: String
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

/// Holds hashes used to generate preview images.
@Observable
public final class MediaImageBlurHashes: Decodable, Equatable, MediaImageBlurHashesProtocol {
    public var primary: String?
    public var logo: String?
    public var backdrop: String?
    
    public enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case logo = "Logo"
        case backdrop = "Backdrop"
    }
    
    public static func == (lhs: MediaImageBlurHashes, rhs: MediaImageBlurHashes) -> Bool {
        lhs.primary == rhs.primary &&
        lhs.logo == rhs.logo &&
        lhs.backdrop == rhs.backdrop
    }
    
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.primary = try container.decodeIfPresent([String: String].self, forKey: .primary)?.values.first
            self.logo = try container.decodeIfPresent([String: String].self, forKey: .logo)?.values.first
            self.backdrop = try container.decodeIfPresent([String: String].self, forKey: .backdrop)?.values.first
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
    
    public init(thumbnail: String?, logo: String?, primary: String?) {
        self.thumbnail = thumbnail
        self.logo = logo
        self.primary = primary
    }
    
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

/// Some media designed to be displayed as an example
public final class ExampleMedia: MediaRepresentableProtocol {
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
    
    public init(title: String) {
        self.title = title
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
