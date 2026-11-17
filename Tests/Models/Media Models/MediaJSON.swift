//
//  MediaJSON.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import Foundation

/// Hands back the `Decoder` for a JSON payload
private struct DecoderCapture: Decodable {
    let decoder: Decoder

    init(from decoder: Decoder) {
        self.decoder = decoder
    }
}

/// Decode a model from JSON text
/// - Parameters:
///   - type: Model to decode
///   - json: JSON text
/// - Returns: The decoded model
func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

/// Wrap JSON text in a `Decoder`, for types that decode through a static function rather than `init(from:)`
/// - Parameter json: JSON text
/// - Returns: A decoder for the top level of the JSON
func decoder(_ json: String) throws -> Decoder {
    try JSONDecoder().decode(DecoderCapture.self, from: Data(json.utf8)).decoder
}
