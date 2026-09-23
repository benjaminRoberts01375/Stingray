//
//  DecoderExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 1/28/26.
//

import Foundation

/// Enable fail-safe array decoding
public extension KeyedDecodingContainer {
    /// Decodes an array, skipping any elements that fail to decode instead of
    /// throwing for the whole array. Returns an empty array if the key is
    /// missing or the container itself can't be found.
    /// - Parameters:
    ///   - type: The element type to decode.
    ///   - key: The key containing the array.
    /// - Returns: Successfully decoded elements; failures are dropped.
    func decodeAllAvailable<T: Decodable>(_ type: [T].Type, forKey key: Key) -> [T] {
        guard let wrapped = try? decode([LossyElement<T>].self, forKey: key)
        else { return [] }
        return wrapped.compactMap { $0.value }
    }
    
    /// Wraps a decode attempt for a single element, capturing failure instead of propagating it.
    private struct LossyElement<T: Decodable>: Decodable {
        let value: T?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.value = try? container.decode(T.self)
        }
    }
}
