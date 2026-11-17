//
//  CollectionModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("Collection Model Init")
@MainActor // For decoding
struct CollectionModelTests {
    /// Test that every field lands on the right property, and that media starts empty
    @Test
    func decodesAllFields() throws {
        let collection = try decode(CollectionModel.self, from: """
        {
            "Id": "collection1",
            "ParentId": "library1",
            "Name": "Blender Open Movies",
            "SortName": "blender open movies",
            "Overview": "Films made with Blender",
            "Genres": ["Animation"],
            "People": [{"Name": "Ton", "Role": "Producer"}],
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}}
        }
        """)

        #expect(collection.id == "collection1")
        #expect(collection.parentID == "library1")
        #expect(collection.title == "Blender Open Movies")
        #expect(collection.sortTitle == "blender open movies")
        #expect(collection.description == "Films made with Blender")
        #expect(collection.genres == ["Animation"])
        #expect(collection.people.map(\.name) == ["Ton"])
        #expect(collection.imageTags?.primary == "p")
        #expect(collection.imageBlurHashes?.primary == "hashP")
        guard case .waiting = collection.media
        else {
            Issue.record("Expected media to start as .waiting, got \(collection.media)")
            return
        }
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    func missingFieldsFallBack() throws {
        let collection = try decode(CollectionModel.self, from: "{}")

        #expect(!collection.id.isEmpty)
        #expect(!collection.parentID.isEmpty)
        #expect(collection.title == "Unknown Collection")
        #expect(collection.sortTitle == "Unknown Collection")
        #expect(collection.description.isEmpty)
        #expect(collection.genres.isEmpty)
        #expect(collection.maturity.isEmpty)
        #expect(collection.releaseDate == nil)
        #expect(collection.duration == nil)
        #expect(collection.people.isEmpty)
        #expect(collection.imageTags?.primary == nil)
        #expect(collection.imageBlurHashes == nil)
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(CollectionModel.self, from: "[]") }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Base Container")
        #expect(object == "Collection Model")
    }
}
