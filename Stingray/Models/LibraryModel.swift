//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

/// A single library on the server, along with the media downloaded into it so far.
public protocol LibraryProtocol: AnyObject, Identifiable {
    /// User-facing name of the library
    var title: String { get }
    /// ID provided by the server
    var id: String { get }
    /// Fetch progress for this library's media. Holds the media itself once any is available
    var media: MediaStatus { get set }
    /// Every genre seen across this library's media, accumulated as pages arrive. Drives the genre filter
    var genres: Set<String> { get set }
    /// Every maturity rating seen across this library's media, accumulated as pages arrive. Drives the maturity filter
    var maturityRatings: Set<String> { get set }
}

/// Denotes the current status of loading media in a library
public enum MediaStatus {
    /// Waiting for the server to respond
    case waiting
    /// Some library content is available, and some may still be downloading
    case available([MediaModel])
    /// Loading library content failed with an error
    case error(RError)
}

/// Holds a single library's metadata and its downloaded media.
@Observable
public final class LibraryModel: LibraryProtocol, Decodable {
    public var title: String
    public var media: MediaStatus
    public var id: String
    public var genres: Set<String>
    public var maturityRatings: Set<String>
    
    /// Create a model for storing a single Library's data
    /// - Parameters:
    ///   - title: User-facing name of the library
    ///   - id: Unique ID of this library
    public init(title: String, id: String) {
        self.title = title
        self.media = .waiting
        self.id = id
        self.genres = []
        self.maturityRatings = []
    }
    
    public enum CodingKeys: String, CodingKey {
        case title = "Name"
        case media = "media"
        case id = "Id"
        case libraryType = "CollectionType"
    }
    
    /// Create a `LibraryModel` from JSON. Media always starts empty, since libraries are paged in separately.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.title = try container.decode(String.self, forKey: .title)
            self.id = try container.decode(String.self, forKey: .id)
            self.media = .waiting
            self.genres = []
            self.maturityRatings = []
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "LibraryModel") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "LibraryModel") }
            else { throw JSONError.failedJSONDecode("LibraryModel", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("LibraryModel", error) }
    }
}
