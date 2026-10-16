//
//  HomeVideoModel.swift
//  Stingray
//
//  Created by Ben Roberts on 10/3/26.
//

import SwiftUI

public protocol HomeVideoProtocol: MediaMetadataProtocol {
    /// All available content sources for this home video
    var mediaSources: [any MediaSourceProtocol] { get }
}

@Observable
public final class HomeVideoModel: HomeVideoProtocol {
    public var title: String
    public var sortTitle: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImagesProtocol)?
    public var id: String
    public var parentID: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    public var mediaSources: [any MediaSourceProtocol]

    // Hashable conformance
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: HomeVideoModel, rhs: HomeVideoModel) -> Bool { lhs.id == rhs.id }

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case parentID = "ParentId"
        case title = "Name"
        case sortTitle = "SortName"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case mediaSources = "MediaSources"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case duration = "RunTimeTicks"
        case people = "People"
    }

    /// Creates a home video from JSON
    /// - Parameter decoder: JSON decoder
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    public init(from decoder: Decoder) throws(JSONError) {
        let container: KeyedDecodingContainer<HomeVideoModel.CodingKeys>
        do { container = try decoder.container(keyedBy: CodingKeys.self) }
        catch { throw JSONError.missingContainer("Base Container", "Home Video Model") }

        // Easy decodable stuff
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        self.parentID = (try? container.decodeIfPresent(String.self, forKey: .parentID)) ?? UUID().uuidString
        let title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Title"
        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageTags = (try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags)) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.maturity = try? container.decodeIfPresent(String.self, forKey: .maturity)
        self.people = (try? container.decodeIfPresent([MediaPerson].self, forKey: .people)) ?? []

        // Runtime ticks need conversion
        if let runtimeTicks = try? container.decodeIfPresent(Int.self, forKey: .duration), runtimeTicks != 0 {
            self.duration = .nanoseconds(100 * runtimeTicks)
        }

        // Date needs to be interpreted
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .releaseDate) {
            self.releaseDate = ISO8601DateFormatter.jellyfin.date(from: dateString)
        }

        // Media sources are only present when requested, ex. they're missing from recently added media
        do { self.mediaSources = try container.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? [] }
        catch { throw JSONError.failedJSONDecode("Home Video Model Media Sources", error) }
    }
}
