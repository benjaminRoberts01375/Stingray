//
//  TVShowModel.swift
//  Stingray
//
//  Created by Ben Roberts on 10/2/26.
//

import SwiftUI

public protocol TVShowProtocol: MediaMetadataProtocol, SpecialFeaturesProtocol {
    /// Short descriptor of the media.
    var tagline: String { get }
    /// Seasons for this TV Show, which contain episodes, which themselves contain media sources
    var seasons: TVSeasonsStatus { get }

    /// Load season data
    func loadSeasons(_ newState: TVSeasonsStatus)
}

/// Describes how to hold information about a TV Season
public protocol TVSeasonProtocol: Identifiable {
    /// A generic ID - Not relevant to the ID of the season set by the server.
    var id: String { get }
    /// Name of the season. Ex: "Special", "Season 2 Cont.", or "Season 1".
    var title: String { get }
    /// Episodes associated with this season.
    var episodes: [any TVEpisodeProtocol] { get set }
}

/// Describes how to hold information about a TV Episode.
public protocol TVEpisodeProtocol: Displayable {
    /// ID given by the server.
    var id: String { get }
    /// Name of the episode.
    var title: String { get }
    /// Episode number in a season.
    var episodeNumber: Int { get }
    /// Media streams for this episode.
    var mediaSources: [any MediaSourceProtocol] { get }
    /// Time it was last played. Nil if it was never played.
    var lastPlayed: Date? { get set }
    /// Longer description of the episode. Nil if none is provided.
    var overview: String? { get }
    /// People who were a part of this episode
    var people: [any MediaPersonProtocol] { get }
}

/// Track the loading status of TV Seasons
public enum TVSeasonsStatus {
    /// Season downloads have yet to start
    case unloaded
    /// Seasons downloads have started for this media
    case loading
    /// Season downloading is complete
    case loaded([any TVSeasonProtocol])
}

@Observable
public final class TVShowModel: TVShowProtocol, Decodable {
    public var title: String
    public var sortTitle: String
    public var tagline: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImagesProtocol)?
    public var id: String
    public var parentID: String
    public var genres: Set<String>
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
        case parentID = "ParentId"
        case seriesID = "SeriesId"
        case seriesTitle = "SeriesName"
        case title = "Name"
        case sortTitle = "SortName"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case duration = "RunTimeTicks"
        case people = "People"
    }

    /// Creates a TV show from JSON
    /// - Parameter decoder: JSON decoder
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    public init(from decoder: Decoder) throws(JSONError) {
        let container: KeyedDecodingContainer<TVShowModel.CodingKeys>
        do { container = try decoder.container(keyedBy: CodingKeys.self) }
        catch { throw JSONError.missingContainer("Base Container", "TV Show Model") }

        // Decodable stuff
        // Prefer the series identity when present (e.g. NextUp returns episodes, but we want the containing show).
        // Fallback to the actual ID
        self.id = (try? container.decodeIfPresent(String.self, forKey: .seriesID)) ??
        (try? container.decodeIfPresent(String.self, forKey: .id)) ??
        UUID().uuidString
        self.parentID = (try? container.decodeIfPresent(String.self, forKey: .parentID)) ?? UUID().uuidString

        let title = (try? container.decodeIfPresent(String.self, forKey: .seriesTitle)) ??
        (try? container.decodeIfPresent(String.self, forKey: .title)) ??
        String(localized: "Unknown TV Show")

        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.tagline = (try? container.decodeIfPresent([String].self, forKey: .taglines))?.first ?? ""
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageTags = (try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags)) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.genres = (try? container.decodeIfPresent(Set<String>.self, forKey: .genres)) ?? []
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

        // We can't yet load these since they're in a separate request
        self.seasons = .unloaded
        self.specialFeatures = .unloaded
    }

    /// Stores and formats the special features for this show.
    /// - Parameter specialFeatures: Special features to add.
    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) {
        self.specialFeatures = .loaded(SpecialFeature.formatAndGroup(specialFeatures))
    }

    /// Stores the show's seasons, and once loaded, merges every episode's people into the show's people.
    /// - Parameter newState: New season loading state.
    public func loadSeasons(_ newState: TVSeasonsStatus) {
        // Save the episodes
        self.seasons = newState

        switch newState {
        case .unloaded, .loading: return
        case .loaded(let newSeasons):
            // Save all the people
            var people: [any MediaPersonProtocol] = self.people
            // We don't use IDs here because people across a series can have different IDs. This prevents duplicates
            var seenIDs: Set<String> = Set(self.people.map { $0.name + $0.role })
            for season in newSeasons {
                for episode in season.episodes {
                    for person in episode.people where seenIDs.insert(person.name + person.role).inserted {
                        people.append(person)
                    }
                }
            }
            self.people = people
        }
    }
}

/// Holds information about a particular TV Season.
@Observable
public final class TVSeason: TVSeasonProtocol {
    public var id: String
    public var title: String
    public var episodes: [any TVEpisodeProtocol]

    /// Create a TVSeason with defined episodes.
    /// - Parameters:
    ///   - title: Name of the season. Ex: "Special", "Season 2 Cont.", or "Season 1".
    ///   - episodes: Episodes associated with the season.
    public init(title: String, episodes: [any TVEpisodeProtocol]) {
        self.id = UUID().uuidString
        self.title = title
        self.episodes = episodes
    }

    /// Decodes an array of TV seasons from a JSON response containing episode data
    /// - Parameter decoder: The decoder to read data from
    /// - Returns: An array of TV seasons with episodes grouped appropriately
    /// - Throws: JSONError if decoding fails
    public static func decodeSeasons(from decoder: Decoder) throws(JSONError) -> [TVSeason] {
        enum CodingKeys: String, CodingKey {
            case items = "Items"
        }

        enum SeasonKeys: String, CodingKey {
            case title = "Name"
            case id = "Id"
            case episodeRuntimeTicks = "RunTimeTicks"
            case episodeNumber = "IndexNumber"
            case episodeOverview = "Overview"
            case seasonNumber = "ParentIndexNumber"
            case blurHashes = "ImageBlurHashes"
            case mediaSources = "MediaSources"
            case userData = "UserData"
            case people = "People"

            case seasonID = "SeasonId" // The actual season ID
            case seasonTitle = "SeasonName" // The actual season name
            case seriesID = "SeriesId" // Fallback for seasonID if SeasonId is missing
        }

        enum UserData: String, CodingKey {
            case lastPlayedDate = "LastPlayedDate"
            case playbackPosition = "PlaybackPositionTicks"
        }

        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var seasonsContainer = try container.nestedUnkeyedContainer(forKey: .items)
            var tempSeasons: [TVSeason] = []
            var standInEpisodeNumber: Int = 0
            var lastSeasonID: String = ""

            while !seasonsContainer.isAtEnd {
                standInEpisodeNumber += 1 // Fallback episode number if it's not present
                let episodeContainer = try seasonsContainer.nestedContainer(keyedBy: SeasonKeys.self)
                let userDataContainer = try episodeContainer.nestedContainer(keyedBy: UserData.self, forKey: .userData)

                let episode: TVEpisode = TVEpisode(
                    id: try episodeContainer.decode(String.self, forKey: .id),
                    blurHashes: try episodeContainer.decodeIfPresent(MediaImageBlurHashes.self, forKey: .blurHashes),
                    title: try episodeContainer.decode(String.self, forKey: .title),
                    episodeNumber: try episodeContainer.decodeIfPresent(Int.self, forKey: .episodeNumber) ?? standInEpisodeNumber,
                    mediaSources: try episodeContainer.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? [],
                    lastPlayed: {
                        guard let dateString = try? userDataContainer.decodeIfPresent(
                            String.self,
                            forKey: .lastPlayedDate
                        ) else { return nil }
                        return ISO8601DateFormatter.jellyfin.date(from: dateString)
                    }(),
                    overview: try episodeContainer.decodeIfPresent(String.self, forKey: .episodeOverview),
                    people: try episodeContainer.decodeIfPresent([MediaPerson].self, forKey: .people) ?? []
                )
                let seasonID = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonID) ??
                episodeContainer.decode(String.self, forKey: .seriesID)

                if let playbackTicks = try userDataContainer.decodeIfPresent(Int.self, forKey: .playbackPosition) {
                    for mediaSourceIndex in episode.mediaSources.indices {
                        episode.mediaSources[mediaSourceIndex].startPoint = TimeInterval(ticks: playbackTicks)
                    }
                }

                let seasonTitle = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season"
                if seasonTitle == "Specials" { // Episode is a special
                    if tempSeasons.last?.title == "Special" { // Coalesce consecutive specials into one Specials season
                        tempSeasons.last?.episodes.append(episode)
                    }
                    else {
                        let newSeason = TVSeason(
                            title: "Special",
                            episodes: [episode]
                        )
                        tempSeasons.append(newSeason)
                    }
                }
                else if seasonID == lastSeasonID && tempSeasons.last?.title == "Special" { // Season was split by specials
                    lastSeasonID = seasonID
                    let newSeason = TVSeason(
                        title: (try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season") +
                        " Cont.",
                        episodes: [episode]
                    )
                    tempSeasons.append(newSeason)
                }
                else if seasonID == lastSeasonID, let lastSeason = tempSeasons.last { // Episode is in the last season
                    lastSeason.episodes.append(episode)
                }
                else { // Episode needs a new season
                    lastSeasonID = seasonID
                    let newSeason = TVSeason(
                        title: try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season",
                        episodes: [episode]
                    )
                    tempSeasons.append(newSeason)
                }
            }
            return tempSeasons
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "TVSeason.decodeSeasons") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "TVSeason.decodeSeasons") }
            else { throw JSONError.failedJSONDecode("Season Media", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("Season Media", error) }
    }
}

/// Holds information about a particular TV Episode.
@Observable
public final class TVEpisode: TVEpisodeProtocol {
    public var imageTags: (any MediaImagesProtocol)?
    public var id: String
    public var imageBlurHashes: (any MediaImagesProtocol)?
    public var title: String
    public var episodeNumber: Int
    public var mediaSources: [any MediaSourceProtocol]
    public var lastPlayed: Date?
    public var overview: String?
    public let people: [any MediaPersonProtocol]

    /// Creates an episode. Built by `TVSeason.decodeSeasons(from:)` rather than decoded directly.
    /// - Parameters:
    ///   - id: ID given by the server
    ///   - blurHashes: Hashes for rendering preview artwork before the real image loads
    ///   - title: Name of the episode
    ///   - episodeNumber: Episode number within its season
    ///   - mediaSources: Playable sources for this episode
    ///   - lastPlayed: When the episode was last watched. `nil` if never
    ///   - overview: Longer description. `nil` if the server has none
    ///   - people: Cast and crew credited on this episode
    public init(
        id: String,
        blurHashes: MediaImageBlurHashes? = nil,
        title: String,
        episodeNumber: Int,
        mediaSources: [any MediaSourceProtocol],
        lastPlayed: Date? = nil,
        overview: String? = nil,
        people: [any MediaPersonProtocol]
    ) {
        self.id = id
        self.imageBlurHashes = blurHashes
        self.title = title
        self.episodeNumber = episodeNumber
        self.mediaSources = mediaSources
        self.lastPlayed = lastPlayed
        self.overview = overview
        self.people = people
    }
}
