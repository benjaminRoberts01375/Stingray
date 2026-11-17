//
//  LibraryModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/13/26.
//

import Foundation
import Testing
@testable import Stingray

private extension LibraryModel {
    /// Build a library by decoding JSON, since `LibraryModel` only has a decoding initializer.
    /// Images are left absent, and media starts as `.waiting`.
    convenience init(
        title: String = "",
        sortTitle: String = "",
        id: String = UUID().uuidString,
        parentID: String = UUID().uuidString
    ) throws {
        let json: [String: String] = ["Name": title, "SortName": sortTitle, "Id": id, "ParentId": parentID]
        let data = try JSONEncoder().encode(json)
        try self.init(from: try decoder(String(decoding: data, as: UTF8.self)))
    }
}

@Suite("Library Model Init")
@MainActor // For decoding
struct LibraryModelTests {
    /// Test that every field lands on the right property, and that media starts empty
    @Test
    func decodesAllFields() throws {
        let library = try decode(LibraryModel.self, from: """
        {
            "Id": "library1",
            "ParentId": "root1",
            "Name": "Movies",
            "SortName": "movies",
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}, "Logo": {"l": "hashL"}, "Backdrop": {"b": "hashB"}}
        }
        """)

        #expect(library.id == "library1")
        #expect(library.parentID == "root1")
        #expect(library.title == "Movies")
        #expect(library.sortTitle == "movies")
        #expect(library.genres.isEmpty)
        #expect(library.maturity.isEmpty)
        #expect(library.imageTags?.primary == "p")
        #expect(library.imageTags?.logo == "l")
        #expect(library.imageTags?.thumbnail == "t")
        #expect(library.imageBlurHashes?.primary == "hashP")
        #expect(library.imageBlurHashes?.logo == "hashL")
        #expect(library.imageBlurHashes?.thumbnail == "hashB")
        guard case .waiting = library.media
        else {
            Issue.record("Expected media to start as .waiting, got \(library.media)")
            return
        }
    }

    /// Test that absent images fall back to empty image tags and no blur hashes
    @Test
    func missingImagesFallBack() throws {
        let library = try decode(LibraryModel.self, from: """
        {"Id": "library1", "ParentId": "root1", "Name": "Movies", "SortName": "movies"}
        """)

        let tags = try #require(library.imageTags)
        #expect(tags.primary == nil)
        #expect(tags.logo == nil)
        #expect(tags.thumbnail == nil)
        #expect(library.imageBlurHashes == nil)
    }

    /// Test that malformed images fall back the same way, rather than failing the whole library
    @Test
    func malformedImagesFallBack() throws {
        let library = try decode(LibraryModel.self, from: """
        {"Id": "library1", "ParentId": "root1", "Name": "Movies", "SortName": "movies", "ImageTags": "oops", "ImageBlurHashes": [1, 2, 3]}
        """)

        #expect(library.id == "library1")
        let tags = try #require(library.imageTags)
        #expect(tags.primary == nil)
        #expect(library.imageBlurHashes == nil)
    }

    /// Test that a missing required key reports which key was missing
    /// - Parameter key: Required JSON key to remove
    @Test(arguments: ["Id", "ParentId", "Name", "SortName"])
    func missingRequiredKeyThrows(key: String) throws {
        var fields = ["Id": "library1", "ParentId": "root1", "Name": "Movies", "SortName": "movies"]
        fields[key] = nil
        let json = String(decoding: try JSONEncoder().encode(fields), as: UTF8.self)

        let error = #expect(throws: JSONError.self) { try decode(LibraryModel.self, from: json) }
        guard case .missingKey(let missing, let object)? = error
        else {
            Issue.record("Expected .missingKey, got \(String(describing: error))")
            return
        }
        #expect(missing == key)
        #expect(object == "LibraryModel")
    }

    /// Test that a `null` required value reports which key was null
    @Test
    func nullRequiredValueThrows() {
        let error = #expect(throws: JSONError.self) {
            try decode(LibraryModel.self, from: """
            {"Id": "library1", "ParentId": "root1", "Name": null, "SortName": "movies"}
            """)
        }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Name")
        #expect(object == "LibraryModel")
    }

    /// Test that a required value of the wrong type is rejected
    @Test
    func wrongTypeThrows() {
        let error = #expect(throws: JSONError.self) {
            try decode(LibraryModel.self, from: """
            {"Id": 5, "ParentId": "root1", "Name": "Movies", "SortName": "movies"}
            """)
        }
        guard case .failedJSONDecode(let object, _)? = error
        else {
            Issue.record("Expected .failedJSONDecode, got \(String(describing: error))")
            return
        }
        #expect(object == "LibraryModel")
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(LibraryModel.self, from: "[]") }
        guard case .failedJSONDecode(let object, _)? = error
        else {
            Issue.record("Expected .failedJSONDecode, got \(String(describing: error))")
            return
        }
        #expect(object == "LibraryModel")
    }
}
