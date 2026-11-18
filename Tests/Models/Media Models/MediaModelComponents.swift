//
//  MediaModelComponents.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation
import Testing
@testable import Stingray

/// Tests for decoding `MediaStorage` (main actor isolated for decoding)
@Suite("Media Storage Init")
@MainActor
public struct MediaStorageTests {
    /// Test that each server media type is decoded into the matching model
    /// - Parameters:
    ///   - serverType: Media type as the server names it
    ///   - expected: Media type the storage should hold
    @Test(arguments: [
        ("Movie", MediaStorage.MediaType.movie),
        ("Series", .tvShow),
        ("Episode", .tvShow),
        ("Video", .homeVideo),
        ("Folder", .subFolder),
        ("BoxSet", .collection),
        ("Playlist", .error)
    ])
    public func decodesMediaType(serverType: String, expected: MediaStorage.MediaType) throws {
        let storage = try decode(MediaStorage.self, from: #"{"Type": "\#(serverType)", "Id": "media1"}"#)
        #expect(storage.mediaType == expected)
    }

    /// Test that media without a type is rejected, since there's no way to know what to build
    @Test
    public func missingTypeThrows() {
        let error = #expect(throws: JSONError.self) { try decode(MediaStorage.self, from: #"{"Id": "media1"}"#) }
        guard case .missingKey(let key, let object)? = error
        else {
            Issue.record("Expected .missingKey, got \(String(describing: error))")
            return
        }
        #expect(key == "Type")
        #expect(object == "Media Storage")
    }
}

/// Tests for decoding `MediaPerson` (main actor isolated for decoding)
@Suite("Media Person Init")
@MainActor
public struct MediaPersonTests {
    /// Test that every field lands on the right property
    @Test
    public func decodesAllFields() throws {
        let person = try decode(MediaPerson.self, from: """
        {"Id": "person1", "Name": "Sacha", "Role": "Director", "ImageBlurHashes": {"Primary": {"p": "hashP"}}}
        """)

        #expect(person.id == "person1")
        #expect(person.name == "Sacha")
        #expect(person.role == "Director")
        #expect(person.imageHashes?.primary == "hashP")
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    public func missingFieldsFallBack() throws {
        let person = try decode(MediaPerson.self, from: "{}")

        #expect(!person.id.isEmpty)
        #expect(person.name == "Anonymous")
        #expect(person.role == "Unknown Roll")
        #expect(person.imageHashes == nil)
    }
}

/// Tests for decoding `MediaImages` (main actor isolated for decoding)
@Suite("Media Images Init")
@MainActor
public struct MediaImagesTests {
    /// Test that each image tag lands on the right property
    @Test
    public func decodesImageTags() throws {
        let images = try decode(MediaImages.self, from: #"{"Primary": "p", "Logo": "l", "Thumb": "t"}"#)

        #expect(images.primary == "p")
        #expect(images.logo == "l")
        #expect(images.thumbnail == "t")
    }

    /// Test that the first hash of each image type is kept, with the backdrop used as the thumbnail
    @Test
    public func decodesBlurHashes() throws {
        let hashes = try decode(MediaImageBlurHashes.self, from: """
        {"Primary": {"p": "hashP"}, "Logo": {"l": "hashL"}, "Backdrop": {"b": "hashB"}}
        """)

        #expect(hashes.primary == "hashP")
        #expect(hashes.logo == "hashL")
        #expect(hashes.thumbnail == "hashB")
    }

    /// Test that missing images decode as absent, rather than failing
    @Test
    public func missingImagesAreNil() throws {
        let images = try decode(MediaImages.self, from: "{}")
        let hashes = try decode(MediaImageBlurHashes.self, from: "{}")

        #expect(images == MediaImages(thumbnail: nil, logo: nil, primary: nil))
        #expect(hashes.primary == nil)
        #expect(hashes.logo == nil)
        #expect(hashes.thumbnail == nil)
    }
}

/// Tests for decoding `MediaSource` (main actor isolated for decoding)
@Suite("Media Source Init")
@MainActor
public struct MediaSourceTests {
    /// Test that streams are split by type, and the server's default audio stream is the only default
    @Test
    public func decodesAllFields() throws {
        let source = try decode(MediaSource.self, from: """
        {
            "Id": "source1",
            "Name": "1080p",
            "RunTimeTicks": 600000000,
            "DefaultAudioStreamIndex": 2,
            "MediaStreams": [
                {"Index": 0, "Type": "Video"},
                {"Index": 1, "Type": "Audio", "IsDefault": true},
                {"Index": 2, "Type": "Audio"},
                {"Index": 3, "Type": "Subtitle"},
                {"Index": 4, "Type": "Attachment"}
            ]
        }
        """)

        #expect(source.id == "source1")
        #expect(source.name == "1080p")
        #expect(source.duration == 60)
        #expect(source.startPoint == 0)
        #expect(source.videoStreams.map(\.id) == ["0"])
        #expect(source.audioStreams.map(\.id) == ["1", "2"])
        #expect(source.audioStreams.map(\.isDefault) == [false, true])
        #expect(source.subtitleStreams.map(\.id) == ["3"])
    }

    /// Test that a source with only its required fields has no streams and no duration
    @Test
    public func missingOptionalFieldsFallBack() throws {
        let source = try decode(MediaSource.self, from: #"{"Id": "source1", "Name": "1080p"}"#)

        #expect(source.duration == 0)
        #expect(source.videoStreams.isEmpty)
        #expect(source.audioStreams.isEmpty)
        #expect(source.subtitleStreams.isEmpty)
    }

    /// Test that a missing required key reports which key was missing
    /// - Parameter key: Required JSON key to remove
    @Test(arguments: ["Id", "Name"])
    public func missingRequiredKey(key: String) {
        var fields = ["\"Id\": \"source1\"", "\"Name\": \"1080p\""]
        fields.removeAll { $0.hasPrefix("\"\(key)\"") }

        let error = #expect(throws: JSONError.self) { try decode(MediaSource.self, from: "{\(fields.joined(separator: ", "))}") }
        guard case .missingKey(let missing, let object)? = error
        else {
            Issue.record("Expected .missingKey when \(key) is absent, got \(String(describing: error))")
            return
        }
        #expect(missing == key)
        #expect(object == "MediaSource")
    }
}

/// Tests for decoding `MediaStream` (main actor isolated for decoding)
@Suite("Media Stream Init")
@MainActor
public struct MediaStreamTests {
    /// Test that every field lands on the right property
    @Test
    public func decodesAllFields() throws {
        let stream = try decode(MediaStream.self, from: """
        {"Index": 1, "DisplayTitle": "English", "Type": "Audio", "BitRate": 320000, "Codec": "aac", "IsDefault": true}
        """)

        #expect(stream.id == "1")
        #expect(stream.title == "English")
        #expect(stream.type == .audio)
        #expect(stream.bitrate == 320000)
        #expect(stream.codec == "aac")
        #expect(stream.isDefault)
    }

    /// Test that an empty object still decodes, using a placeholder for every field
    @Test
    public func missingFieldsFallBack() throws {
        let stream = try decode(MediaStream.self, from: "{}")

        #expect(!stream.id.isEmpty)
        #expect(stream.title == "Unknown stream")
        #expect(stream.type == .unknown)
        #expect(stream.bitrate == 10000)
        #expect(stream.codec.isEmpty)
        #expect(!stream.isDefault)
    }

    /// Test that AV1 streams ask for a higher bitrate, since they'll be transcoded
    @Test
    public func av1BoostsBitrate() throws {
        let stream = try decode(MediaStream.self, from: #"{"Type": "Video", "BitRate": 1000, "Codec": "av1"}"#)
        #expect(stream.bitrate == 1750)
    }
}

/// Tests for decoding `SpecialFeature` (main actor isolated for decoding)
@Suite("Special Feature Init")
@MainActor
public struct SpecialFeatureTests {
    /// Test that every field lands on the right property
    @Test
    public func decodesAllFields() throws {
        let feature = try decode(SpecialFeature.self, from: """
        {
            "Id": "feature1",
            "ExtraType": "BehindTheScenes",
            "MediaSources": [{"Id": "source1", "Name": "1080p"}],
            "ImageTags": {"Primary": "p"},
            "ImageBlurHashes": {"Primary": {"p": "hashP"}}
        }
        """)

        #expect(feature.id == "feature1")
        #expect(feature.featureType == "BehindTheScenes")
        #expect(feature.mediaSources.map(\.id) == ["source1"])
        #expect(feature.imageTags?.primary == "p")
        #expect(feature.imageBlurHashes?.primary == "hashP")
    }

    /// Test that optional images decode as absent
    @Test
    public func missingImagesAreNil() throws {
        let feature = try decode(SpecialFeature.self, from: #"{"Id": "feature1", "ExtraType": "Trailer", "MediaSources": []}"#)

        #expect(feature.imageTags == nil)
        #expect(feature.imageBlurHashes == nil)
    }

    /// Test that a missing required key fails the feature
    /// - Parameter key: Required JSON key to remove
    @Test(arguments: ["Id", "ExtraType", "MediaSources"])
    public func missingRequiredKeyThrows(key: String) {
        var fields = ["\"Id\": \"feature1\"", "\"ExtraType\": \"Trailer\"", "\"MediaSources\": []"]
        fields.removeAll { $0.hasPrefix("\"\(key)\"") }

        #expect(throws: DecodingError.self) { try decode(SpecialFeature.self, from: "{\(fields.joined(separator: ", "))}") }
    }
}
