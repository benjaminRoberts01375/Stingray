//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

public protocol LibraryProtocol: Identifiable {
    var title: String { get }
    var media: MediaStatus { get }
}

/// Denotes the current status of loading media in a library
public enum MediaStatus {
    /// An unloaded state of the library, ready to be triggered
    case unloaded
    /// Waiting for the server to respond
    case waiting
    /// Library content is available
    case available([MediaModel])
    /// Loading library content failed with an error
    case error(Error)
}

@Observable
public final class LibraryModel: LibraryProtocol, Decodable {
    public var title: String
    public var media: MediaStatus
    public var id: String
    
    init(title: String, id: String) {
        self.title = title
        self.media = .unloaded
        self.id = id
    }
    
    enum CodingKeys: String, CodingKey {
        case title = "Name"
        case media = "media"
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
    }
}
