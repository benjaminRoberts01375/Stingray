//
//  DecoderExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// An extension to offer safer alternatives to decoding
extension KeyedDecodingContainer {
    /// Decoding made safe.
    /// - Parameters:
    ///   - type: Type to decode to
    ///   - key: JSON key to decode
    ///   - defaultValue: Fallback value to use if unable to decode
    ///   - errBucket: Bucket to append errors to
    ///   - errLabel: Label denoting the object which owns this key
    /// - Returns: The decoded value for the given key, if possible
    func decodeFieldSafely<T: Decodable>(
        _ type: T.Type,
        forKey key: Key,
        default defaultValue: T,
        errBucket: inout [RError],
        errLabel: String
    ) -> T {
        do { return try decodeIfPresent(type, forKey: key) ?? { throw JSONError.missingKey(key.description, errLabel) }() }
        catch let error as JSONError { // Missing key
            errBucket.append(error)
            return defaultValue
        }
        catch { // Generic JSON decode error
            errBucket.append(JSONError.failedJSONDecode(key.description, error))
            return defaultValue
        }
    }
}
