//
//  URLExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import Foundation

extension URL {
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL? {
        guard let url = URL(string: path, relativeTo: self) else {
            return nil
        }
        
        // Add query parameters if provided
        if let urlParams = urlParams, !urlParams.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = urlParams
            return components?.url
        }
        return url
    }
}
