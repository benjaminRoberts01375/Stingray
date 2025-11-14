//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol Library: Identifiable {
    var title: String { get }
    var media: [MediaProtocol] { get }
}


public final class LibraryModel: Library, Decodable {
    public var title: String
    public var media: [MediaProtocol]
    public var id: String
    
    init(title: String, media: [MediaModel] = [], id: String) {
        self.title = title
        self.media = media
        self.id = id
    }
    
    enum CodingKeys: String, CodingKey {
        case title = "Name"
        case media
        case id = "Id"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            self.title = try container.decode(String.self, forKey: .title)
        } catch {
            print("Failed to decode title: \(error)")
            throw error
        }
        
        do {
            self.id = try container.decode(String.self, forKey: .id)
        } catch {
            print("Failed to decode id: \(error)")
            throw error
        }
        self.media = [] // Don't even try to decode media here
    }
}
