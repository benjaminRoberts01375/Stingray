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
    
    func loadMedia(streamingService: any StreamingServiceProtocol) async throws {
        let batchSize = 50
        var currentIndex = 0
        var allMedia: [MediaModel] = []
        
        // Preserve existing media if we're adding to it
        if case .available(let existingMedia) = self.media {
            allMedia = existingMedia
        }
        
        // Keep fetching batches until we get fewer items than the batch size
        while true {
            let incomingMedia = try await streamingService.getLibraryMedia(
                libraryID: self.id,
                index: currentIndex,
                count: batchSize,
                sortOrder: .Ascending,
                sortBy: .SortName
            )
            
            allMedia.append(contentsOf: incomingMedia)
            
            // Update the UI after each batch
            media = .available(allMedia)
            
            // If we received fewer items than requested, we've reached the end
            if incomingMedia.count < batchSize {
                break
            }
            
            currentIndex += batchSize
        }
    }
}
