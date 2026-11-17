//
//  SubFolderModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("Sub-Folder Model Init")
@MainActor // For decoding
struct SubFolderModelTests {
    /// Test that every field lands on the right property, and that media starts empty
    @Test
    func decodesAllFields() throws {
        let folder = try decode(SubFolderModel.self, from: """
        {
            "Id": "folder1",
            "ParentId": "library1",
            "Name": "Vacations",
            "SortName": "vacations",
            "Overview": "Trips we took",
            "Genres": ["Travel"],
            "People": [{"Name": "Dad", "Role": "Driver"}],
            "ImageTags": {"Primary": "p", "Logo": "l", "Thumb": "t"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}}
        }
        """)

        #expect(folder.id == "folder1")
        #expect(folder.parentID == "library1")
        #expect(folder.title == "Vacations")
        #expect(folder.sortTitle == "vacations")
        #expect(folder.description == "Trips we took")
        #expect(folder.genres == ["Travel"])
        #expect(folder.people.map(\.name) == ["Dad"])
        #expect(folder.imageTags?.primary == "p")
        #expect(folder.imageBlurHashes?.primary == "hashP")
        guard case .waiting = folder.media
        else {
            Issue.record("Expected media to start as .waiting, got \(folder.media)")
            return
        }
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    func missingFieldsFallBack() throws {
        let folder = try decode(SubFolderModel.self, from: "{}")

        #expect(!folder.id.isEmpty)
        #expect(!folder.parentID.isEmpty)
        #expect(folder.title == "Unknown Sub-Folder")
        #expect(folder.sortTitle == "Unknown Sub-Folder")
        #expect(folder.description.isEmpty)
        #expect(folder.genres.isEmpty)
        #expect(folder.maturity.isEmpty)
        #expect(folder.releaseDate == nil)
        #expect(folder.duration == nil)
        #expect(folder.people.isEmpty)
        #expect(folder.imageTags?.primary == nil)
        #expect(folder.imageBlurHashes == nil)
    }

    /// Test that JSON that isn't an object is rejected
    @Test
    func nonObjectThrows() {
        let error = #expect(throws: JSONError.self) { try decode(SubFolderModel.self, from: "[]") }
        guard case .missingContainer(let key, let object)? = error
        else {
            Issue.record("Expected .missingContainer, got \(String(describing: error))")
            return
        }
        #expect(key == "Base Container")
        #expect(object == "Sub-Folder Model")
    }
}
