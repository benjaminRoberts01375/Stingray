//
//  MediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol MediaProtocol: Decodable {
    var title: String { get }
    var description: String { get }
    var logoArtURL: String { get }
    var boxArtURL: String { get }
    var backgroundArtURL: String { get }
}

@Observable
final class MediaModel: MediaProtocol {
    var title: String
    var description: String
    var logoArtURL: String
    var boxArtURL: String
    var backgroundArtURL: String
    
    init(title: String, description: String, logoArtURL: String, boxArtURL: String, backgroundArtURL: String) {
        self.title = title
        self.description = description
        self.logoArtURL = logoArtURL
        self.boxArtURL = boxArtURL
        self.backgroundArtURL = backgroundArtURL
    }
}
