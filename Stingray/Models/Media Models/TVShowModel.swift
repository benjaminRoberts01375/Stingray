//
//  TVShowModel.swift
//  Stingray
//
//  Created by Ben Roberts on 10/2/26.
//

import SwiftUI

public protocol TVShowProtocol: MediaRepresentableProtocol {
    /// Short descriptor of the media.
    var tagline: String { get }
    /// Seasons for this TV Show, which contain episodes, which themselves contain media sources
    var seasons: TVSeasonsStatus { get }
    /// Tracks if the special features have been fetched. If they have been successfully fetched, they'll available through this variable.
    var specialFeatures: SpecialFeaturesStatus { get }

    /// Load special features for this media
    func loadSpecialFeatures(specialFeatures: [SpecialFeature])
    /// Load season data
    func loadSeasons(_ newState: TVSeasonsStatus)
}

@Observable
public final class TVShowModel: TVShowProtocol, Decodable {
    public var title: String
    public var sortTitle: String
    public var tagline: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    public var specialFeatures: SpecialFeaturesStatus
    public var seasons: TVSeasonsStatus

    // Hashable conformance
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: TVShowModel, rhs: TVShowModel) -> Bool { lhs.id == rhs.id }

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case sortTitle = "SortName"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case people = "People"
    }

    /// Creates a TV show from JSON
    /// - Parameter decoder: JSON decoder
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<TVShowModel.CodingKeys>
        do { container = try decoder.container(keyedBy: CodingKeys.self) }
        catch { throw JSONError.missingContainer("Base Container", "TV Show Model") }

        // Decodable stuff
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        let title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Title"
        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.tagline = (try? container.decodeIfPresent([String].self, forKey: .taglines))?.first ?? ""
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageTags = (try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags)) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.maturity = try? container.decodeIfPresent(String.self, forKey: .maturity)
        self.people = (try? container.decodeIfPresent([MediaPerson].self, forKey: .people)) ?? []

        // We can't yet load these since they're in a separate request
        self.seasons = .unloaded
        self.specialFeatures = .unloaded
    }

    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) {  } // TODO: TV Show special features

    public func loadSeasons(_ newState: TVSeasonsStatus) {  } // TODO: TV Show load seasons - set state, aggregate genres and people
}
