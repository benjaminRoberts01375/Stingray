//
//  URLExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import Foundation

/// Extend the URL type to quickly add parameters to a URL
extension URL {
    /// Quickly add URL parameters to a URL
    /// - Parameters:
    ///   - path: Relative path to a resource (e.g., "/Users/AuthenticateByName")
    ///   - urlParams: Parameters to add
    /// - Returns: The built URL
    ///
    /// This method properly handles base URLs with paths (e.g., https://example.com/jellyfin)
    /// by appending the new path instead of replacing it. This fixes issue #7 where
    /// Jellyfin servers behind a reverse proxy with a subpath couldn't connect.
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL? {
        // Use URLComponents to properly construct the URL
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        // Get the existing base path (e.g., "/jellyfin" from "https://example.com/jellyfin")
        let basePath = components.path
        
        // Construct the full path by combining base path with the API path
        // Handle cases where basePath might be empty or just "/"
        let normalizedBasePath = basePath == "/" ? "" : basePath
        
        // Remove leading slash from path if base path exists to avoid double slashes
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        
        // Combine paths
        components.path = normalizedBasePath + normalizedPath
        
        // Add query parameters if provided
        if let urlParams = urlParams, !urlParams.isEmpty {
            // Preserve any existing query items and add new ones
            var existingItems = components.queryItems ?? []
            existingItems.append(contentsOf: urlParams)
            components.queryItems = existingItems
        }
        
        return components.url
    }
}
