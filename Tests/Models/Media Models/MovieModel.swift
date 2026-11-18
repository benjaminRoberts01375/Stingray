//
//  MovieModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation
import Testing
@testable import Stingray

/// Tests for decoding `MovieModel` (main actor isolated for decoding)
@Suite("Movie Model Init")
@MainActor
public struct MovieModelTests {
    /// Test that every field lands on the right property
    @Test
    public func decodesAllFields() throws {
        let movie = try decode(MovieModel.self, from: """
        {
            "Id": "movie1",
            "ParentId": "library1",
            "Name": "Big Buck Bunny",
            "SortName": "big buck bunny",
            "Taglines": ["First tagline", "Second tagline"],
            "Overview": "A large rabbit",
            "Genres": ["Animation", "Comedy"],
            "OfficialRating": "PG",
            "PremiereDate": "2001-01-01T00:00:00.0000000Z",
            "RunTimeTicks": 72000000000,
            "People": [{"Name": "Sacha", "Role": "Director"}],
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}},
            "MediaSources": [{"Id": "source1", "Name": "1080p"}]
        }
        """)

        #expect(movie.id == "movie1")
        #expect(movie.parentID == "library1")
        #expect(movie.title == "Big Buck Bunny")
        #expect(movie.sortTitle == "big buck bunny")
        #expect(movie.tagline == "First tagline")
        #expect(movie.description == "A large rabbit")
        #expect(movie.genres == ["Animation", "Comedy"])
        #expect(movie.maturity == "PG")
        #expect(movie.releaseDate == Date(timeIntervalSinceReferenceDate: 0))
        #expect(movie.duration == .seconds(7200))
        #expect(movie.people.map(\.name) == ["Sacha"])
        #expect(movie.imageTags?.primary == "p")
        #expect(movie.imageBlurHashes?.primary == "hashP")
        #expect(movie.mediaSources.map(\.id) == ["source1"])
        guard case .unloaded = movie.specialFeatures
        else {
            Issue.record("Expected special features to start as .unloaded, got \(movie.specialFeatures)")
            return
        }
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    public func missingFieldsFallBack() throws {
        let movie = try decode(MovieModel.self, from: "{}")

        #expect(!movie.id.isEmpty)
        #expect(!movie.parentID.isEmpty)
        #expect(movie.title == "Unknown Movie")
        #expect(movie.sortTitle == "Unknown Movie")
        #expect(movie.tagline == nil)
        #expect(movie.description.isEmpty)
        #expect(movie.genres.isEmpty)
        #expect(movie.maturity == nil)
        #expect(movie.releaseDate == nil)
        #expect(movie.duration == nil)
        #expect(movie.people.isEmpty)
        #expect(movie.imageTags?.primary == nil)
        #expect(movie.imageBlurHashes == nil)
        #expect(movie.mediaSources.isEmpty)
    }

    /// Test that the sort title falls back to the title rather than the placeholder
    @Test
    public func sortTitleFallsBackToTitle() throws {
        let movie = try decode(MovieModel.self, from: #"{"Name": "Sintel"}"#)
        #expect(movie.sortTitle == "Sintel")
    }

    /// Test that values of the wrong shape are treated as missing, rather than failing the whole movie
    @Test
    public func invalidValuesFallBack() throws {
        let movie = try decode(MovieModel.self, from: """
        {"Name": 5, "Genres": "Drama", "PremiereDate": "Yesterday", "RunTimeTicks": 0}
        """)

        #expect(movie.title == "Unknown Movie")
        #expect(movie.genres.isEmpty)
        #expect(movie.releaseDate == nil)
        #expect(movie.duration == nil)
    }

    /// Test that the playback position is applied only to the version of the movie that was last played
    @Test
    public func resumesLastPlayedSource() throws {
        let movie = try decode(MovieModel.self, from: """
        {
            "MediaSources": [{"Id": "source1", "Name": "1080p"}, {"Id": "source2", "Name": "4K"}],
            "UserData": {"PlaybackPositionTicks": 600000000, "ItemId": "source2"}
        }
        """)

        #expect(movie.mediaSources[0].startPoint == 0)
        #expect(movie.mediaSources[1].startPoint == 60)
    }

    /// Test that a broken media source fails the movie, since it couldn't be played
    @Test
    public func invalidMediaSourceThrows() {
        let error = #expect(throws: JSONError.self) {
            try decode(MovieModel.self, from: #"{"MediaSources": [{"Name": "No ID"}]}"#)
        }
        guard case .failedJSONDecode(let object, _)? = error
        else {
            Issue.record("Expected .failedJSONDecode, got \(String(describing: error))")
            return
        }
        #expect(object == "Movie Model Media Sources")
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    public func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(MovieModel.self, from: "[]") }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Base Container")
        #expect(object == "Movie Model")
    }
}
