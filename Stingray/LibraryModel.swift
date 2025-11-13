//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

final class LibraryModel {
    var title: String
    
    var media: [MediaModel]
    
    init(title: String, media: [MediaModel] = []) {
        self.title = title
        self.media = media
    }
}
