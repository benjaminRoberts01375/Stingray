//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol Library: Identifiable, Decodable {
    var title: String { get }
    var media: [MediaProtocol] { get }
}


final class LibraryModel: Library {
    var title: String
    var media: [MediaProtocol]
    let id: String
    
    init(title: String, media: [MediaModel] = [], id: String) {
        self.title = title
        self.media = media
        self.id = id
    }
}
