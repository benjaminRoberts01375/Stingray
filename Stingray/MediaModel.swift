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
    var logoArtURL: String { get }
    var boxArtURL: String { get }
    var backgroundArtURL: String { get }
}

@Observable
final class MediaModel: MediaProtocol, Decodable {
    var title: String
    var description: String
    var logoArtURL: String
    var boxArtURL: String
    var backgroundArtURL: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case logoArtURL
        case boxArtURL
        case backgroundArtURL
    }
    
    init(title: String, description: String, logoArtURL: String, boxArtURL: String, backgroundArtURL: String) {
        self.title = title
        self.description = description
        self.logoArtURL = logoArtURL
        self.boxArtURL = boxArtURL
        self.backgroundArtURL = backgroundArtURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.logoArtURL = try container.decode(String.self, forKey: .logoArtURL)
        self.boxArtURL = try container.decode(String.self, forKey: .boxArtURL)
        self.backgroundArtURL = try container.decode(String.self, forKey: .backgroundArtURL)
    }
}
