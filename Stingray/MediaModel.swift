//
//  MediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol MediaProtocol {
    var title: String { get }
    var description: String { get }
    var ImageTags: MediaImages { get }
    var id: String { get }
}

@Observable
public final class MediaModel: MediaProtocol, Decodable, Identifiable, Hashable {
    public var title: String
    public var tagline: String
    public var description: String
    public var ImageTags: MediaImages
    public var imageBlurHashes: MediaImageBlurHashes?
    public var id: String
    
    public static func == (lhs: MediaModel, rhs: MediaModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
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
    }
}

public struct MediaImages: Decodable, Equatable, Hashable {
    var thumbnail: String?
    var logo: String?
    var primary: String?
    
    enum CodingKeys: String, CodingKey {
        case thumbnail = "Thumb"
        case logo = "Logo"
        case primary = "Primary"
    }
}

public struct MediaImageBlurHashes: Decodable, Equatable, Hashable {
    var primary: [String: String]?
    var thumb: [String: String]?
    var logo: [String: String]?
    var backdrop: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case thumb = "Thumb"
        case logo = "Logo"
        case backdrop = "Backdrop"
    }
    
    /// Helper to get the first blur hash from a dictionary
    func getBlurHash(for key: MediaImageType) -> String? {
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
