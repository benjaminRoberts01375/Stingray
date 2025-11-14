//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol Library: Identifiable {
    var title: String { get }
    var media: MediaStatus { get }
}

public enum MediaStatus {
    case unloaded
    case waiting
    case available([MediaProtocol])
    case error(Error)
}


public final class LibraryModel: Library, Decodable {
    public var title: String
    public var media: MediaStatus
    public var id: String
    
    init(title: String, id: String) {
        self.title = title
        self.media = .unloaded
        self.id = id
        print("Title: \(title)")
        print("ID: \(id)")
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
        self.media = .unloaded // Don't even try to decode media here
        print("Title: \(title)")
        print("ID: \(id)")
    }
}
