//
//  HomeVideoModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("Home Video Model Init")
@MainActor // For decoding
struct HomeVideoModelTests {
    /// Test that every field lands on the right property
    @Test
    func decodesAllFields() throws {
        let video = try decode(HomeVideoModel.self, from: """
        {
            "Id": "video1",
            "ParentId": "library1",
            "Name": "Birthday Party",
            "SortName": "birthday party",
            "Taglines": ["First tagline", "Second tagline"],
            "Overview": "Cake was had",
            "Genres": ["Family"],
            "OfficialRating": "G",
            "PremiereDate": "2001-01-01T00:00:00.0000000Z",
            "RunTimeTicks": 6000000000,
            "People": [{"Name": "Grandma", "Role": "Camera"}],
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}},
            "MediaSources": [{"Id": "source1", "Name": "720p"}]
        }
        """)

        #expect(video.id == "video1")
        #expect(video.parentID == "library1")
        #expect(video.title == "Birthday Party")
        #expect(video.sortTitle == "birthday party")
        #expect(video.tagline == "First tagline")
        #expect(video.description == "Cake was had")
        #expect(video.genres == ["Family"])
        #expect(video.maturity == "G")
        #expect(video.releaseDate == Date(timeIntervalSinceReferenceDate: 0))
        #expect(video.duration == .seconds(600))
        #expect(video.people.map(\.name) == ["Grandma"])
        #expect(video.imageTags?.primary == "p")
        #expect(video.imageBlurHashes?.primary == "hashP")
        #expect(video.mediaSources.map(\.id) == ["source1"])
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    func missingFieldsFallBack() throws {
        let video = try decode(HomeVideoModel.self, from: "{}")

        #expect(!video.id.isEmpty)
        #expect(!video.parentID.isEmpty)
        #expect(video.title == "Unknown Home Video")
        #expect(video.sortTitle == "Unknown Home Video")
        #expect(video.tagline == nil)
        #expect(video.description.isEmpty)
        #expect(video.genres.isEmpty)
        #expect(video.maturity == nil)
        #expect(video.releaseDate == nil)
        #expect(video.duration == nil)
        #expect(video.people.isEmpty)
        #expect(video.imageTags?.primary == nil)
        #expect(video.imageBlurHashes == nil)
        #expect(video.mediaSources.isEmpty)
    }

    /// Test that values of the wrong shape are treated as missing, rather than failing the whole video
    @Test
    func invalidValuesFallBack() throws {
        let video = try decode(HomeVideoModel.self, from: """
        {"Name": 5, "Genres": "Family", "PremiereDate": "Yesterday", "RunTimeTicks": 0}
        """)

        #expect(video.title == "Unknown Home Video")
        #expect(video.genres.isEmpty)
        #expect(video.releaseDate == nil)
        #expect(video.duration == nil)
    }

    /// Test that a broken media source fails the video, since it couldn't be played
    @Test
    func invalidMediaSourceThrows() {
        let error = #expect(throws: JSONError.self) {
            try decode(HomeVideoModel.self, from: #"{"MediaSources": [{"Name": "No ID"}]}"#)
        }
        guard case .failedJSONDecode(let object, _)? = error
        else {
            Issue.record("Expected .failedJSONDecode, got \(String(describing: error))")
            return
        }
        #expect(object == "Home Video Model Media Sources")
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(HomeVideoModel.self, from: "[]") }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Base Container")
        #expect(object == "Home Video Model")
    }
}
