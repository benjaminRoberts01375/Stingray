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

public enum MediaStatus {
    case unloaded
    case waiting
    case available([MediaModel])
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
    
    func loadMedia(networkAPI: AdvancedNetworkProtocol, accessToken: String) async throws {
        print("Loading media for \(self.title) with ID \(self.id)")
        let incomingMedia = try await networkAPI.getLibraryMedia(accessToken: accessToken, libraryId: self.id, index: 0, count: 2000, sortOrder: .Ascending, sortBy: .SortName, mediaTypes: [.movies, .tv])
        switch self.media {
        case .unloaded, .waiting, .error:
            media = .available(incomingMedia)
        case .available(let existingMedia):
            media = .available(existingMedia + incomingMedia)
        }
    }
}
