//
//  TopShelfItem.swift
//  TopShelf
//
//  Created by Ben Roberts on 10/16/26.
//

import Foundation

/// The few fields of a server item the Top Shelf renders.
/// Decoded locally instead of through the app's media models, which carry far more than a title and some artwork.
public struct TopShelfItem: Decodable {
    /// ID of the media to open. For episodes, this is the show they belong to
    let id: String?
    /// ID of the media's parent, which the app needs to find the media again from a deep link
    let parentID: String?
    /// Name to show under the artwork
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case seriesID = "SeriesId"
        case parentID = "ParentId"
        case title = "Name"
        case seriesTitle = "SeriesName"
    }

    /// Never throws, so a single malformed item doesn't take down the rest of a row.
    /// - Parameter decoder: JSON decoder
    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        // Up Next returns episodes, but the app opens the show they belong to, so prefer the series identity when present
        self.id = (try? container?.decodeIfPresent(String.self, forKey: .seriesID)) ??
            (try? container?.decodeIfPresent(String.self, forKey: .id))
        self.parentID = try? container?.decodeIfPresent(String.self, forKey: .parentID)
        self.title = (try? container?.decodeIfPresent(String.self, forKey: .seriesTitle)) ??
            (try? container?.decodeIfPresent(String.self, forKey: .title))
    }
}

/// Artwork shapes the Top Shelf requests, named as the server expects them.
public enum TopShelfImageType: String {
    /// A vertical movie poster
    case primary = "Primary"
    /// A horizontal image of the media
    case backdrop = "Backdrop"
}
