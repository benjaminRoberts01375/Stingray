//
//  APINetwork.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit
import SwiftUI

public protocol BasicNetworkProtocol {
    func request<T: Decodable>(verb: NetworkRequestType, path: String, headers: [String : String]?, urlParams: [URLQueryItem]?, body: (any Encodable)?) async throws -> T
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL?
    func buildAVPlayerItem(path: String, urlParams: [URLQueryItem]?, headers: [String : String]?) -> AVPlayerItem?
}

public enum NetworkRequestType: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case encodeJSONFailed(Error)
    case requestFailedToSend(Error)
    case badResponse(responseCode: Int, response: String?)
    case decodeJSONFailed(Error)
    case missingAccessToken
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodeJSONFailed (let error):
            return "Unable to encode JSON: \(error.localizedDescription)"
        case .requestFailedToSend(let error):
            return "The request failed to send: \(error.localizedDescription)"
        case .badResponse(let responseCode, let response):
            return "Got a bad response from the server. Error: \(responseCode), \(response ?? "Unknown error")"
        case .decodeJSONFailed(let error):
            return "Unable to decode JSON: \(error.localizedDescription)"
        case .missingAccessToken:
            return "Missing access token"
        }
    }
}

public enum MediaType: String, Decodable {
    case collections = "BoxSet"
    case movies = "Movie"
    case tv = "Series"
}

public protocol AdvancedNetworkProtocol {
    func login(username: String, password: String) async throws -> APILoginResponse
    func getLibraries(accessToken: String) async throws -> [LibraryModel]
    func getLibraryMedia(accessToken: String, libraryId: String, index: Int, count: Int, sortOrder: LibraryMediaSortOrder, sortBy: LibraryMediaSortBy, mediaTypes: [MediaType]?) async throws -> [MediaModel]
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, imageID: String, width: Int) -> URL?
    func getStreamingContent(accessToken: String, contentID: String, streamID: String, bitrate: Int, subtitleID: Int?, audioID: Int, videoID: Int) -> AVPlayerItem?
}

public enum LibraryMediaSortOrder: String {
    case Ascending = "Ascending"
    case Descending = "Descending"
}

public enum LibraryMediaSortBy: String {
    case Default = "Default"
    case AiredEpisodeOrder = "AiredEpisodeOrder"
    case Album = "Album"
    case Artist = "AlbumArtist"
    case DateCreated = "DateCreated"
    case OfficialRating = "OfficialRating"
    case DatePlayed = "DatePlayed"
    case ReleaseDate = "PremiereDate"
    case StartDate = "StartDate"
    /// Sort by user-given aliases and fallback to the original name
    case SortName = "SortName"
    /// Sort by the original name
    case Name = "Name"
    case Random = "Random"
    case Runtime = "Runtime"
    case CommunityRating = "CommunityRating"
    case ProductionYear = "ProductionYear"
    case PlayCount = "PlayCount"
    case CriticRating = "CriticRating"
    case IsFolder = "IsFolder"
    case IsPlayed = "IsPlayed"
    case SeriesSortName = "SeriesSortName"
    case Bitrate = "VideoBitRate"
    case AirTime = "AirTime"
    case Studio = "Studio"
    case IsFavorite = "IsFavoriteOrLiked"
    case DateLastContentAdded = "DateLastContentAdded"
    case SeriesDatePlayed = "SeriesDatePlayed"
    case ParentIndexNumber = "ParentIndexNumber"
    case IndexNumber = "IndexNumber"
}

public enum MediaImageType: String {
    case thumbnail = "Thumb"
    case logo = "Logo"
    case primary = "Primary"
    case backdrop = "Backdrop"
}

public struct APILoginResponse: Decodable {
    let userName: String
    let sessionId: String
    let userId: String
    let accessToken: String
    let serverId: String
    
    var description: String {
        return "User's name: \(userName), SessionID: \(sessionId), userID: \(userId), accessToken: \(accessToken), serverID: \(serverId)"
    }
    
    enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
    
    enum UserKeys: String, CodingKey {
        case name = "Name"
    }
    
    enum SessionInfoKeys: String, CodingKey {
        case id = "Id"
        case userId = "UserId"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode nested User
        let userContainer = try container.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        userName = try userContainer.decode(String.self, forKey: .name)
        
        // Decode nested SessionInfo
        let sessionContainer = try container.nestedContainer(keyedBy: SessionInfoKeys.self, forKey: .sessionInfo)
        sessionId = try sessionContainer.decode(String.self, forKey: .id)
        userId = try sessionContainer.decode(String.self, forKey: .userId)
        
        // Decode flat fields
        accessToken = try container.decode(String.self, forKey: .accessToken)
        serverId = try container.decode(String.self, forKey: .serverId)
    }
}

final class JellyfinBasicNetwork: BasicNetworkProtocol {
    var address: URL
    
    init(address: URL) {
        self.address = address
    }
    
    func request<T: Decodable>(verb: NetworkRequestType, path: String, headers: [String : String]? = nil, urlParams: [URLQueryItem]? = nil, body: (any Encodable)? = nil) async throws -> T {
        // Setup URL with path
        guard let url = self.buildURL(path: path, urlParams: urlParams) else {
            throw NetworkError.invalidURL
        }
        
        print("Reaching out to \(url.absoluteString)")
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = verb.rawValue
        
        // Jellyfin headers
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let authHeader = "MediaBrowser Client=\"Stingray\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(appVersion)\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        // Only add custom headers if they are provided
        if let headers = headers {
            for header in headers {
                request.setValue(header.1, forHTTPHeaderField: header.0)
            }
        }
        
        // Only encode body if one is provided
        if let body = body {
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Set JSON as content type
                request.httpBody = jsonData
            } catch (let error) {
                throw NetworkError.encodeJSONFailed(error)
            }
        }
        
        // Send the request
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch (let error) {
            throw NetworkError.requestFailedToSend(error)
        }
        
        // Verify not invalid status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(responseCode: 0, response: "Not an HTTP response")
        }
        
        // Verify non-bad status code
        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.badResponse(responseCode: httpResponse.statusCode, response: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
        
        // Decode the JSON response with more helpful errors
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
            return decodedResponse
        } catch let DecodingError.dataCorrupted(context) {
            throw NetworkError.decodeJSONFailed(DecodingError.dataCorrupted(context))
        } catch let DecodingError.keyNotFound(key, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.keyNotFound(key, context))
        } catch let DecodingError.valueNotFound(value, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.valueNotFound(value, context))
        } catch let DecodingError.typeMismatch(type, context)  {
            throw NetworkError.decodeJSONFailed(DecodingError.typeMismatch(type, context))
        } catch {
            throw NetworkError.decodeJSONFailed(error)
        }
    }
    
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL? {
        guard var url = URL(string: path, relativeTo: address) else {
            return nil
        }
        
        // Add query parameters if provided
        if let urlParams = urlParams, !urlParams.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = urlParams
            guard let urlWithParams = components?.url else { return nil }
            url = urlWithParams
        }
        
        return url
    }
    
    func buildAVPlayerItem(path: String, urlParams: [URLQueryItem]?, headers: [String : String]?) -> AVPlayerItem? {
        guard let url = buildURL(path: path, urlParams: urlParams) else { return nil }
        print(url.absoluteString)
        // Configure asset options with proper HTTP headers
        var options: [String: Any] = [:]
        if let headers = headers {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        
        let asset = AVURLAsset(url: url, options: options)
        return AVPlayerItem(asset: asset)
    }
}

final class JellyfinAdvancedNetwork: AdvancedNetworkProtocol {
    var network: BasicNetworkProtocol
    
    init(network: BasicNetworkProtocol) {
        self.network = network
    }
    
    func login(username: String, password: String) async throws -> APILoginResponse {
        struct Response: Codable {
            let User: User
            let SessionInfo: SessionInfo
            let AccessToken: String
            let ServerId: String
        }
        
        struct User: Codable {
            let Name: String
        }
        
        struct SessionInfo: Codable {
            let Id: String
            let UserId: String
        }
        
        let requestBody: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        return try await network.request(verb: .post, path: "/Users/AuthenticateByName", headers: nil, urlParams: nil, body: requestBody)
    }
    
    func getLibraries(accessToken: String) async throws -> [LibraryModel] {
        struct Root: Decodable {
            let items: [LibraryModel]
            
            enum CodingKeys: String, CodingKey {
                case items = "Items"
            }
        }
        let root: Root = try await network.request(verb: .get, path: "/Library/MediaFolders", headers: ["X-MediaBrowser-Token":accessToken], urlParams: nil, body: nil)
        return root.items
    }
    
    func getLibraryMedia(accessToken: String, libraryId: String, index: Int, count: Int, sortOrder: LibraryMediaSortOrder, sortBy: LibraryMediaSortBy, mediaTypes: [MediaType]?) async throws -> [MediaModel] {
        struct Root: Decodable {
            let items: [MediaModel]
            
            enum CodingKeys: String, CodingKey {
                case items = "Items"
            }
        }
        var params : [URLQueryItem] = [
            URLQueryItem(name: "sortOrder", value: sortOrder.rawValue),
            URLQueryItem(name: "sortBy", value: sortBy.rawValue),
            URLQueryItem(name: "startIndex", value: "\(index)"),
            URLQueryItem(name: "limit", value: "\(count)"),
            URLQueryItem(name: "parentId", value: libraryId),
            URLQueryItem(name: "fields", value: "MediaSources"),
            URLQueryItem(name: "fields", value: "Taglines"),
            URLQueryItem(name: "fields", value: "Genres")
        ]
        
        for mediaType in mediaTypes ?? [] {
            params.append(URLQueryItem(name: "includeItemTypes", value: mediaType.rawValue))
        }
        
        let response: Root = try await network.request(verb: .get, path: "/Items", headers: ["X-MediaBrowser-Token":accessToken], urlParams: params, body: nil)
        return response.items
    }
    
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, imageID: String, width: Int) -> URL? {
        let params : [URLQueryItem] = [
            URLQueryItem(name: "fillWidth", value: String(width)),
            URLQueryItem(name: "quality", value: "95")
        ]
        
        return network.buildURL(path: "/Items/\(imageID)/Images/\(imageType.rawValue)", urlParams: params)
    }
    
    func getStreamingContent(accessToken: String, contentID: String, streamID: String, bitrate: Int, subtitleID: Int?, audioID: Int, videoID: Int) -> AVPlayerItem? {
        let params : [URLQueryItem] = [
            URLQueryItem(name: "playSessionID", value: UUID().uuidString),
            URLQueryItem(name: "mediaSourceID", value: streamID),
            URLQueryItem(name: "audioCodec", value: "mp3"),
            URLQueryItem(name: "videoCodec", value: "h264"),
            URLQueryItem(name: "videoBitRate", value: String(bitrate)),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"), // Burning in subtitles on everything for now
            subtitleID != nil ? URLQueryItem(name: "subtitleStreamIndex", value: String(subtitleID ?? 0)) : nil, // Burning in subtitles on everything for now
            URLQueryItem(name: "audioStreamIndex", value: String(audioID)),
            URLQueryItem(name: "videoStreamIndex", value: String(videoID))
        ].compactMap{$0}
        return network.buildAVPlayerItem(path: "/Videos/\(contentID)/master.m3u8", urlParams: params, headers: ["X-MediaBrowser-Token":accessToken])
    }
}
