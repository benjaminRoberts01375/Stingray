//
//  DecoderExtension.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/9/26.
//

import Foundation
import Testing
@testable import Stingray

@Suite("KeyedDecodingContainer.decodeAllAvailable(_:forKey:)")
struct DecodeAllAvailableTests {
    /// Minimal container that routes its `items` key through `decodeAllAvailable`
    private struct Wrapper<T: Decodable>: Decodable {
        let items: [T]

        enum CodingKeys: String, CodingKey {
            case items
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.items = container.decodeAllAvailable([T].self, forKey: .items)
        }
    }

    /// Simple keyed element used to verify non-primitive element types
    private struct Item: Decodable, Equatable {
        let id: Int
    }

    /// Decode a JSON string through `Wrapper` and return the surviving elements
    private func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> [T] {
        try JSONDecoder().decode(Wrapper<T>.self, from: Data(json.utf8)).items
    }

    /// Test arrays where every element is valid. Should result in every element being kept.
    /// - Parameters:
    ///   - json: JSON payload to decode
    ///   - expected: Decoded output
    @Test(arguments: [
        (#"{"items": []}"#, []),
        (#"{"items": [1]}"#, [1]),
        (#"{"items": [1, 2, 3]}"#, [1, 2, 3]),
        (#"{"items": [-5, 0, 5]}"#, [-5, 0, 5]),
    ] as [(String, [Int])])
    func decodesAllValid(json: String, expected: [Int]) throws {
        #expect(try decode(json, as: Int.self) == expected)
    }

    /// Test arrays containing a mix of valid and invalid elements. Should drop only the invalid elements, preserving order.
    /// - Parameters:
    ///   - json: JSON payload to decode
    ///   - expected: Decoded output with invalid elements removed
    @Test(arguments: [
        (#"{"items": [1, "two", 3]}"#, [1, 3]),
        (#"{"items": [null, 1]}"#, [1]),
        (#"{"items": [1, null]}"#, [1]),
        (#"{"items": [1.5, 2]}"#, [2]),
        (#"{"items": [{}, 2, []]}"#, [2]),
        (#"{"items": [true, 1, "1", 2]}"#, [1, 2]),
    ] as [(String, [Int])])
    func decodesSkippingInvalid(json: String, expected: [Int]) throws {
        #expect(try decode(json, as: Int.self) == expected)
    }

    /// Test arrays where every element is invalid. Should result in an empty array.
    /// - Parameter json: JSON payload to decode
    @Test(arguments: [
        #"{"items": [null]}"#,
        #"{"items": ["a", "b"]}"#,
        #"{"items": [{}, [], 1.5]}"#,
    ])
    func decodesAllInvalid(json: String) throws {
        #expect(try decode(json, as: Int.self).isEmpty)
    }

    /// Test payloads where the key is missing or isn't an array. Should result in an empty array instead of throwing.
    /// - Parameter json: JSON payload to decode
    @Test(arguments: [
        #"{}"#,
        #"{"other": [1, 2]}"#,
        #"{"items": null}"#,
        #"{"items": 1}"#,
        #"{"items": "1, 2"}"#,
        #"{"items": {"0": 1}}"#,
    ])
    func decodesMissingOrMistyped(json: String) throws {
        #expect(try decode(json, as: Int.self).isEmpty)
    }

    /// Test keyed elements where some are missing required fields. Should drop only the malformed elements.
    /// - Parameters:
    ///   - json: JSON payload to decode
    ///   - expected: IDs of the surviving elements
    @Test(arguments: [
        (#"{"items": [{"id": 1}, {"id": 2}]}"#, [1, 2]),
        (#"{"items": [{"id": 1}, {"name": "x"}, {"id": 3}]}"#, [1, 3]),
        (#"{"items": [{"id": "1"}, {"id": 2}]}"#, [2]),
        (#"{"items": [{"id": 1, "extra": true}]}"#, [1]),
        (#"{"items": [{"id": 10000}, {"id": null}, {"id": 30000}]}"#, [10000, 30000]),
    ] as [(String, [Int])])
    func decodesKeyedElements(json: String, expected: [Int]) throws {
        #expect(try decode(json, as: Item.self).map(\.id) == expected)
    }
}
