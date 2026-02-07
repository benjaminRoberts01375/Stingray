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
    /// Some library content is available, and some may still be downloading
    case available([MediaModel])
    /// All library content is available
    case complete([MediaModel])
    /// Loading library content failed with an error
    case error(RError)
}

@Observable
public final class LibraryModel: LibraryProtocol, Decodable {
    public var title: String
    public var media: MediaStatus
    public var id: String
    public var libraryType: String
    
    init(title: String, id: String, libraryType: String) {
        self.title = title
        self.media = .unloaded
        self.id = id
        self.libraryType = libraryType
    }
    
    enum CodingKeys: String, CodingKey {
        case title = "Name"
        case media = "media"
        case id = "Id"
        case libraryType = "CollectionType"
    }
    
    public init(from decoder: Decoder) throws(JSONError) {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            title = try container.decode(String.self, forKey: .title)
            id = try container.decode(String.self, forKey: .id)
            libraryType = try container.decodeIfPresent(String.self, forKey: .libraryType) ?? ""
            media = .unloaded
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "LibraryModel") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "LibraryModel") }
            else { throw JSONError.failedJSONDecode("LibraryModel", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("LibraryModel", error) }
    }
}
