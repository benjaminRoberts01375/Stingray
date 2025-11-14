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
        case title
        case tagline
        case description
        case imageThumbnail
        case imageLogo
        case imagePrimary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.tagline = try container.decode(String.self, forKey: .tagline)
        self.description = try container.decode(String.self, forKey: .description)
        self.ImageTags = MediaImages(
            thumbnail: try container.decode(String.self, forKey: .imageThumbnail),
            logo: try container.decode(String.self, forKey: .imageLogo),
            primary: try container.decode(String.self, forKey: .imagePrimary)
        )
    }
}

public struct MediaImages {
    var thumbnail: String?
    var logo: String?
    var primary: String?
}
