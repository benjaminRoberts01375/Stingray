//
//  LibraryModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/13/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("Library Model Init")
@MainActor // We're decoding a lot, which must be on the main thread
struct LibraryModelTests {
    /// Build library JSON, letting a test override or remove individual entries
    /// - Parameter overrides: Raw JSON values keyed by field. A `nil` value removes the field entirely.
    /// - Returns: JSON data for a library
    private func libraryJSON(_ overrides: [String: String?] = [:]) -> Data {
        var fields: [String: String?] = [
            "Name": "\"Movies\"",
            "SortName": "\"movies\"",
            "Id": "\"abc123\"",
            "ParentId": "\"parent456\""
        ]
        fields.merge(overrides) { _, new in new }
        let body = fields.compactMap { key, value in value.map { "\"\(key)\": \($0)" } }.joined(separator: ", ")
        return Data("{\(body)}".utf8)
    }

    /// Decode a library, expecting it to throw
    /// - Parameter data: JSON data
    /// - Returns: The thrown `JSONError`, or `nil` if decoding succeeded or threw something else
    private func decodeError(_ data: Data) -> JSONError? {
        do {
            _ = try JSONDecoder().decode(LibraryModel.self, from: data)
            return nil
        } catch {
            return error as? JSONError
        }
    }

    /// Test that every required field lands on the right property, and that media starts empty
    @Test
    func decodesRequiredFields() throws {
        let library = try JSONDecoder().decode(LibraryModel.self, from: self.libraryJSON())

        #expect(library.title == "Movies")
        #expect(library.sortTitle == "movies")
        #expect(library.id == "abc123")
        #expect(library.parentID == "parent456")
        #expect(library.genres.isEmpty)
        #expect(library.maturity.isEmpty)
        guard case .waiting = library.media
        else {
            Issue.record("Expected media to start as .waiting, got \(library.media)")
            return
        }
    }

    /// Test that a missing required key reports which key was missing
    /// - Parameter key: Required JSON key to remove
    @Test(arguments: ["Name", "SortName", "Id", "ParentId"])
    func missingRequiredKey(key: String) {
        guard case .missingKey(let missing, let object) = self.decodeError(self.libraryJSON([key: nil]))
        else {
            Issue.record("Expected .missingKey when \(key) is absent")
            return
        }
        #expect(missing == key)
        #expect(object == "LibraryModel")
    }

    /// Test that a `null` required value reports a missing container
    @Test
    func nullRequiredValue() {
        guard case .missingContainer(let key, let object) = self.decodeError(self.libraryJSON(["Name": "null"]))
        else {
            Issue.record("Expected .missingContainer when Name is null")
            return
        }
        #expect(key == "Name")
        #expect(object == "LibraryModel")
    }

    /// Test that a value of the wrong type is reported as a general decode failure
    @Test
    func wrongTypeFailsDecode() {
        guard case .failedJSONDecode(let object, _) = self.decodeError(self.libraryJSON(["Id": "5"]))
        else {
            Issue.record("Expected .failedJSONDecode when Id is a number")
            return
        }
        #expect(object == "LibraryModel")
    }

    /// Test that absent image data decodes to empty tags and no blur hashes, rather than failing
    @Test
    func missingImagesAreTolerated() throws {
        let library = try JSONDecoder().decode(LibraryModel.self, from: self.libraryJSON())

        #expect(library.imageTags?.thumbnail == nil)
        #expect(library.imageTags?.logo == nil)
        #expect(library.imageTags?.primary == nil)
        #expect(library.imageBlurHashes == nil)
    }

    /// Test that present image data is decoded into the image properties
    @Test
    func decodesImages() throws {
        let data = self.libraryJSON([
            "ImageTags": "{\"Primary\": \"p\", \"Logo\": \"l\", \"Thumb\": \"t\"}",
            "ImageBlurHashes": "{\"Primary\": {\"p\": \"hashP\"}, \"Logo\": {\"l\": \"hashL\"}, \"Backdrop\": {\"b\": \"hashB\"}}"
        ])
        let library = try JSONDecoder().decode(LibraryModel.self, from: data)

        #expect(library.imageTags?.primary == "p")
        #expect(library.imageTags?.logo == "l")
        #expect(library.imageTags?.thumbnail == "t")
        #expect(library.imageBlurHashes?.primary == "hashP")
        #expect(library.imageBlurHashes?.logo == "hashL")
        #expect(library.imageBlurHashes?.thumbnail == "hashB")
    }

    /// Test that malformed image data doesn't prevent the library itself from decoding
    @Test
    func malformedImagesAreTolerated() throws {
        let data = self.libraryJSON(["ImageTags": "\"oops\"", "ImageBlurHashes": "[1, 2, 3]"])
        let library = try JSONDecoder().decode(LibraryModel.self, from: data)

        #expect(library.id == "abc123")
        #expect(library.imageTags?.primary == nil)
        #expect(library.imageBlurHashes == nil)
    }
}
