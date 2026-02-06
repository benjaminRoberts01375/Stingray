//
//  SlimMediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// A slimmed down version of the `MediaModelProtocol` for faster loading.
public protocol SlimMediaProtocol: Displayable, Identifiable, Hashable {
    /// ID provided by the server.
    var id: String { get }
    /// Name of this media.
    var title: String { get }
    /// Setup errors. Nil if setup was complete without issue.
    var errors: [RError]? { get }
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
    var primary: [String: String]? { get }
    /// Logo hashes
    var logo: [String: String]? { get }
    /// Backdrop hashes
    var backdrop: [String: String]? { get }
    
    /// Request a type of blur hash
    func getBlurHash(for key: MediaImageType) -> String?
}

/// Denotes the type of image desired. Ex. a horizontal vs vertical movie poster image.
public enum MediaImageType: String {
    /// Fancy text of the media's name.
    case logo = "Logo"
    /// The most frequently used media image type. A vertical movie poster
    case primary = "Primary"
    /// A more action-packed horizontal image of the media
    case backdrop = "Backdrop"
}

/// A slimmed down version of the `MediaModel` for faster loading.
@Observable
public final class SlimMedia: SlimMediaProtocol, Decodable {
    public var id: String
    public var title: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    /// A useful ID for linking this object with the full-sized `MediaModel` object.
    public var parentID: String?
    public var errors: [any RError]?
    
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
    
    /// Create a `SlimMedia` from JSON.
    /// - Parameter decoder: JSON Decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var errBucket: [any RError] = []
        
        self.id = container.decodeFieldSafely(
            String.self,
            forKey: .seriesID,
            default: container.decodeFieldSafely(
                String.self,
                forKey: .id,
                default: UUID().uuidString,
                errBucket: &errBucket,
                errLabel: "Slim Media",
                required: false
            ),
            errBucket: &errBucket,
            errLabel: "Slim Media",
            required: false
        )
        
        self.parentID = container.decodeFieldSafely(
            String?.self,
            forKey: .parentID,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Slim Media",
            required: false
        )
        
        self.title = container.decodeFieldSafely(
            String.self,
            forKey: .seriesTitle,
            default: container.decodeFieldSafely(
                String.self,
                forKey: .title,
                default: "Unknown Title",
                errBucket: &errBucket,
                errLabel: "Slim Media",
                required: false
            ),
            errBucket: &errBucket,
            errLabel: "Slim Media",
            required: false
        )
        
        self.imageBlurHashes = container.decodeFieldSafely(
            MediaImageBlurHashes?.self,
            forKey: .imageBlurHashes,
            default: nil,
            errBucket: &errBucket,
            errLabel: "Slim Media",
            required: false
        )
        
        self.imageTags = container.decodeFieldSafely(
            MediaImages.self,
            forKey: .imageTags,
            default: MediaImages(thumbnail: nil, logo: nil, primary: nil),
            errBucket: &errBucket,
            errLabel: "Slim Media",
            required: false
        )
        
        if !errBucket.isEmpty { errors = errBucket } // Otherwise nil
    }
    
    // Hashable conformance
    public static func == (lhs: SlimMedia, rhs: SlimMedia) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Holds hashes used to generate preview images.
@Observable
public final class MediaImageBlurHashes: Decodable, Equatable, MediaImageBlurHashesProtocol {
    public var primary: [String: String]?
    public var logo: [String: String]?
    public var backdrop: [String: String]?
    
    enum CodingKeys: String, CodingKey {
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
            self.primary = try container.decodeIfPresent([String: String].self, forKey: .primary)
            self.logo = try container.decodeIfPresent([String: String].self, forKey: .logo)
            self.backdrop = try container.decodeIfPresent([String: String].self, forKey: .backdrop)
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "Media Image Blur Hash") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "Media Image Blur Hash") }
            else { throw JSONError.failedJSONDecode("Media Image Blur Hash", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch let error { throw JSONError.failedJSONDecode("Media Image Blur Hash", error) }
    }
    
    public func getBlurHash(for key: MediaImageType) -> String? {
        switch key {
        case .primary:
            return primary?.values.first
        case .logo:
            return logo?.values.first
        case .backdrop:
            return backdrop?.values.first
        }
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
