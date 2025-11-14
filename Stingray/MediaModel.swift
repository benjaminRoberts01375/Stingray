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
public final class MediaModel: MediaProtocol, Decodable, Identifiable {
    public var title: String
    public var tagline: String
    public var description: String
    public var ImageTags: MediaImages
    public var id: String
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
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
        
        self.id = try container.decode(String.self, forKey: .id)
    }
}

public struct MediaImages: Decodable {
    var thumbnail: String?
    var logo: String?
    var primary: String?
    
    enum CodingKeys: String, CodingKey {
        case thumbnail = "Thumb"
        case logo = "Logo"
        case primary = "Primary"
    }
}
