//
//  MediaModelRepresentable.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// A slimmed down version of the `MediaModelProtocol` for faster loading.
public protocol MediaRepresentableProtocol: Displayable, Identifiable, Hashable {
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

/// The slimmest possible MediaModel for faster loading.
@Observable
public final class MediaModelRepresentable: MediaRepresentableProtocol, Decodable {
    public var id: String
    public var title: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    /// A useful ID for linking this object with the full-sized `MediaModel` object.
    public var parentID: String?
    
    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case seriesID = "SeriesId"
        case seriesTitle = "SeriesName"
        case title = "Name"
        case imageBlurHashes = "ImageBlurHashes"
        case imageTags = "ImageTags"
        case parentID = "ParentId"
        case parentPrimaryImage = "SeriesPrimaryImageTag"
    }
    
    /// Create a `MediaModelRepresentable` from JSON.
    /// - Parameter decoder: JSON Decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? (
            (try? container.decodeIfPresent(String.self, forKey: .seriesID)) ??
            UUID().uuidString
        )

        self.parentID = try? container.decodeIfPresent(String.self, forKey: .parentID)

        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? (
            (try? container.decodeIfPresent(String.self, forKey: .seriesTitle))
            ?? "Unknown Title"
        )

        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.imageTags = try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
    }
    
    // Hashable conformance
    public static func == (lhs: MediaModelRepresentable, rhs: MediaModelRepresentable) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
        self.id = UUID().uuidString
        self.imageBlurHashes = nil
        self.imageTags = MediaImages(thumbnail: "Example", logo: "Example", primary: "Example")
    }
}
