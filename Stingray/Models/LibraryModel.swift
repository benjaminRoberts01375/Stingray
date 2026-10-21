//
//  LibraryModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

/// A single library on the server, along with the media downloaded into it so far.
public protocol LibraryProtocol: AnyObject, Identifiable, GroupMetadataProtocol {
    /// User-facing name of the library
    var title: String { get }
    /// ID provided by the server
    var id: String { get }

    // Swift is overly aggressive about setters in nested protocols, so putting this down twice to fix it
    var genres: Set<String> { get set }
    var maturity: Set<String> { get set }
    var media: MediaStatus { get set }
}

/// The descriptive metadata shared by every kind of group of media.
public protocol GroupMetadataProtocol: Identifiable, MetadataProtocol {
    /// Rating of the content in this group provided by the server. Ex. PG, PG-13, R.
    var maturity: Set<String> { get set }
    /// Fetch progress for this library's media. Holds the media itself once any is available
    var media: MediaStatus { get set }
}

/// Denotes the current status of loading media in a library
public enum MediaStatus {
    /// Waiting for the server to respond
    case waiting
    /// Some library content is available, and some may still be downloading
    case available([MediaStorage])
    /// Loading library content failed with an error
    case error(RError)
}

/// Holds a single library's metadata and its downloaded media.
@Observable
public final class LibraryModel: LibraryProtocol, Decodable {
    public var title: String
    public var sortTitle: String
    public var media: MediaStatus
    public var id: String
    public var parentID: String
    public var genres: Set<String>
    public var maturity: Set<String>
    
    public enum CodingKeys: String, CodingKey {
        case title = "Name"
        case sortTitle = "SortName"
        case media = "media"
        case id = "Id"
        case parentID = "ParentId"
        case libraryType = "CollectionType"
    }
    
    /// Create a `LibraryModel` from JSON. Media always starts empty, since libraries are paged in separately.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.title = try container.decode(String.self, forKey: .title)
            self.sortTitle = try container.decode(String.self, forKey: .sortTitle)
            self.id = try container.decode(String.self, forKey: .id)
            self.parentID = try container.decode(String.self, forKey: .parentID)
            self.media = .waiting
            self.genres = []
            self.maturity = []
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "LibraryModel") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "LibraryModel") }
            else { throw JSONError.failedJSONDecode("LibraryModel", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("LibraryModel", error) }
    }
}
