//
//  TVShowModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//
//  Time for some complexity!

import Foundation
import Testing
@testable import Stingray

@Suite("TV Show Model Init")
@MainActor // For decoding
struct TVShowModelTests {
    /// Test that every field lands on the right property
    @Test
    func decodesAllFields() throws {
        let show = try decode(TVShowModel.self, from: """
        {
            "Id": "show1",
            "ParentId": "library1",
            "Name": "Cosmos Laundromat",
            "SortName": "cosmos laundromat",
            "Taglines": ["First tagline", "Second tagline"],
            "Overview": "A sheep on an island",
            "Genres": ["Animation", "Drama"],
            "OfficialRating": "TV-14",
            "PremiereDate": "2001-01-01T00:00:00.0000000Z",
            "RunTimeTicks": 6000000000,
            "People": [{"Name": "Mathieu", "Role": "Director"}],
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}}
        }
        """)

        #expect(show.id == "show1")
        #expect(show.parentID == "library1")
        #expect(show.title == "Cosmos Laundromat")
        #expect(show.sortTitle == "cosmos laundromat")
        #expect(show.tagline == "First tagline")
        #expect(show.description == "A sheep on an island")
        #expect(show.genres == ["Animation", "Drama"])
        #expect(show.maturity == "TV-14")
        #expect(show.releaseDate == Date(timeIntervalSinceReferenceDate: 0))
        #expect(show.duration == .seconds(600))
        #expect(show.people.map(\.name) == ["Mathieu"])
        #expect(show.imageTags?.primary == "p")
        #expect(show.imageBlurHashes?.primary == "hashP")
        guard case .unloaded = show.seasons, case .unloaded = show.specialFeatures
        else {
            Issue.record("Expected seasons and special features to start as .unloaded")
            return
        }
    }

    /// Test that an episode (ex. from up next) is represented by the show it belongs to
    @Test
    func prefersSeriesIdentity() throws {
        let show = try decode(TVShowModel.self, from: """
        {"Id": "episode1", "Name": "Pilot", "SeriesId": "show1", "SeriesName": "Cosmos Laundromat"}
        """)

        #expect(show.id == "show1")
        #expect(show.title == "Cosmos Laundromat")
        #expect(show.sortTitle == "Cosmos Laundromat")
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    func missingFieldsFallBack() throws {
        let show = try decode(TVShowModel.self, from: "{}")

        #expect(!show.id.isEmpty)
        #expect(!show.parentID.isEmpty)
        #expect(show.title == "Unknown TV Show")
        #expect(show.sortTitle == "Unknown TV Show")
        #expect(show.tagline == nil)
        #expect(show.description.isEmpty)
        #expect(show.genres.isEmpty)
        #expect(show.maturity == nil)
        #expect(show.releaseDate == nil)
        #expect(show.duration == nil)
        #expect(show.people.isEmpty)
        #expect(show.imageTags?.primary == nil)
        #expect(show.imageBlurHashes == nil)
    }

    /// Test that values of the wrong shape are treated as missing, rather than failing the whole show
    @Test
    func invalidValuesFallBack() throws {
        let show = try decode(TVShowModel.self, from: """
        {"Name": 5, "Genres": "Drama", "PremiereDate": "Yesterday", "RunTimeTicks": 0}
        """)

        #expect(show.title == "Unknown TV Show")
        #expect(show.genres.isEmpty)
        #expect(show.releaseDate == nil)
        #expect(show.duration == nil)
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(TVShowModel.self, from: "[]") }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Base Container")
        #expect(object == "TV Show Model")
    }
}

@Suite("TV Season Decoding")
@MainActor // For decoding
struct TVSeasonTests {
    /// Build the JSON for a minimal episode
    /// - Parameters:
    ///   - id: Episode ID
    ///   - season: Name of the season the episode belongs to
    ///   - seasonID: ID of the season the episode belongs to
    /// - Returns: JSON for a single episode
    private func episode(_ id: String, season: String, seasonID: String) -> String {
        """
        {"Id": "\(id)", "Name": "Episode \(id)", "SeasonName": "\(season)", "SeasonId": "\(seasonID)", "UserData": {}}
        """
    }

    /// Decode seasons from a list of episodes
    /// - Parameter episodes: JSON for each episode, in order
    /// - Returns: Decoded seasons
    private func seasons(_ episodes: String...) throws -> [TVSeason] {
        try TVSeason.decodeSeasons(from: decoder(#"{"Items": [\#(episodes.joined(separator: ", "))]}"#))
    }

    /// Test that episodes are grouped into their seasons, in order
    @Test
    func groupsEpisodesBySeason() throws {
        let seasons = try self.seasons(
            self.episode("1", season: "Season 1", seasonID: "s1"),
            self.episode("2", season: "Season 1", seasonID: "s1"),
            self.episode("3", season: "Season 2", seasonID: "s2")
        )

        #expect(seasons.map(\.title) == ["Season 1", "Season 2"])
        #expect(seasons.map { $0.episodes.map(\.id) } == [["1", "2"], ["3"]])
    }

    /// Test that specials are gathered into one season, and the season they interrupt is continued afterwards
    @Test
    func specialsSplitSeasons() throws {
        let seasons = try self.seasons(
            self.episode("1", season: "Season 1", seasonID: "s1"),
            self.episode("sp1", season: "Specials", seasonID: "specials"),
            self.episode("sp2", season: "Specials", seasonID: "specials"),
            self.episode("2", season: "Season 1", seasonID: "s1")
        )

        #expect(seasons.map(\.title) == ["Season 1", "Special", "Season 1 Cont."])
        #expect(seasons.map { $0.episodes.map(\.id) } == [["1"], ["sp1", "sp2"], ["2"]])
    }

    /// Test that every episode field lands on the right property
    @Test
    func decodesEpisodeFields() throws {
        let seasons = try self.seasons("""
        {
            "Id": "episode1",
            "Name": "Pilot",
            "IndexNumber": 4,
            "Overview": "It begins",
            "SeasonName": "Season 1",
            "SeasonId": "s1",
            "People": [{"Name": "Franck", "Role": "Sheep"}],
            "ImageBlurHashes": {"Primary": {"p": "hashP"}},
            "MediaSources": [{"Id": "source1", "Name": "1080p"}, {"Id": "source2", "Name": "4K"}],
            "UserData": {"LastPlayedDate": "2001-01-01T00:00:00.0000000Z", "PlaybackPositionTicks": 600000000}
        }
        """)
        let episode = try #require(seasons.first?.episodes.first)

        #expect(episode.id == "episode1")
        #expect(episode.title == "Pilot")
        #expect(episode.episodeNumber == 4)
        #expect(episode.overview == "It begins")
        #expect(episode.people.map(\.name) == ["Franck"])
        #expect(episode.imageBlurHashes?.primary == "hashP")
        #expect(episode.lastPlayed == Date(timeIntervalSinceReferenceDate: 0))
        #expect(episode.mediaSources.map(\.startPoint) == [60, 60])
    }

    /// Test that optional episode fields fall back, with the episode number taken from the episode's position
    @Test
    func episodeFieldsFallBack() throws {
        let seasons = try self.seasons(
            self.episode("1", season: "Season 1", seasonID: "s1"),
            #"{"Id": "2", "Name": "Episode 2", "SeriesId": "show1", "UserData": {}}"#
        )
        let episode = try #require(seasons.last?.episodes.first)

        #expect(seasons.last?.title == "Unknown Season")
        #expect(episode.episodeNumber == 2)
        #expect(episode.overview == nil)
        #expect(episode.lastPlayed == nil)
        #expect(episode.people.isEmpty)
        #expect(episode.mediaSources.isEmpty)
        #expect(episode.imageBlurHashes == nil)
    }

    /// Test that a missing required episode key reports which key was missing
    /// - Parameter key: Required JSON key to remove
    @Test(arguments: ["Id", "Name", "UserData"])
    func missingRequiredKey(key: String) {
        var fields = ["\"Id\": \"1\"", "\"Name\": \"Pilot\"", "\"SeasonId\": \"s1\"", "\"UserData\": {}"]
        fields.removeAll { $0.hasPrefix("\"\(key)\"") }

        let error = #expect(throws: JSONError.self) { try self.seasons("{\(fields.joined(separator: ", "))}") }
        guard case .missingKey(let missing, let object)? = error
        else {
            Issue.record("Expected .missingKey when \(key) is absent, got \(String(describing: error))")
            return
        }
        #expect(missing == key)
        #expect(object == "TVSeason.decodeSeasons")
    }
}
