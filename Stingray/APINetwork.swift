//
//  APINetwork.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit
import SwiftUI

/// A very basic network protocol for sending/receving requests, as well as formatting options
public protocol BasicNetworkProtocol {
    /// Makes a web REST request
    /// - Parameters:
    ///   - verb: Type of REST request
    ///   - path: URL path without hostname, leading slashes, or URL params
    ///   - headers: Headers to add to request
    ///   - urlParams: URL paramaters for data fields
    ///   - body: For sending more advanced data structures like JSON
    /// - Returns: A formatted response in a Decodable type
    func request<T: Decodable>(
        verb: NetworkRequestType,
        path: String,
        headers: [String : String]?,
        urlParams: [URLQueryItem]?,
        body: (any Encodable)?
    ) async throws -> T
    
    /// Allows simple URL building using the URL type.
    /// - Parameters:
    ///   - path: Path to a particular resource without the hostname, leading slashes, or URL params
    ///   - urlParams: URL params to add to URL
    /// - Returns: Formatted URL
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL?
    
    /// Build an AVPlayerItem from a URL
    /// - Parameters:
    ///   - path: Path to a particular resource without the hostname, leading slashes, or URL params
    ///   - urlParams: URL params to add to URL
    ///   - headers: Headers, primarily for authentication
    /// - Returns: A formatted AVPlayerItem ready for streaming
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
    case decodeJSONFailed(Error, url: URL?)
    case missingAccessToken
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodeJSONFailed(let error):
            return "Unable to encode JSON: \(error.localizedDescription)"
        case .requestFailedToSend(let error):
            return "The request failed to send: \(error.localizedDescription)"
        case .badResponse(let responseCode, let response):
            return "Got a bad response from the server. Error: \(responseCode), \(response ?? "Unknown error")"
        case .decodeJSONFailed(let error, let url):
            let urlString = url?.absoluteString ?? "unknown URL"
            // Provide detailed information about decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON from \(urlString): Missing key '\(key.stringValue)' at \(path)"
                case .valueNotFound(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON from \(urlString): Missing value of type '\(type)' at \(path)"
                case .typeMismatch(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON from \(urlString): Type mismatch for '\(type)' at \(path). \
                        \(context.debugDescription)
                        """
                case .dataCorrupted(let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON from \(urlString): Data corrupted at \(path). \
                        \(context.debugDescription)
                        """
                @unknown default:
                    return "Unable to decode JSON from \(urlString): \(error.localizedDescription)"
                }
            }
            return "Unable to decode JSON from \(urlString): \(error.localizedDescription)"
        case .missingAccessToken:
            return "Missing access token"
        }
    }
}

public enum MediaType: Decodable {
    case collections
    case movies([any MediaSourceProtocol])
    case tv([TVSeason]?)
    
    public init (from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        
        switch stringValue {
        case MediaType.collections.rawValue:
            self = .collections
        case "Movie":
            self = .movies([])
        case "Series":
            self = .tv(nil)
        default:
            fatalError("Unknown media type: \(stringValue)")
        }
    }
    
    var rawValue: String {
        switch self {
        case .collections:
            return "BoxSet"
        case .movies:
            return "Movie"
        case .tv:
            return "Series"
        }
    }
}

/// Defines a network that is reliant on primitives already created by `BasicNetworkProtocol`
public protocol AdvancedNetworkProtocol {
    /// Log-in a user via a username and password
    /// - Parameters:
    ///   - username: User's username
    ///   - password: User's password
    /// - Returns: Credentials and user data from server
    func login(username: String, password: String) async throws -> APILoginResponse
    /// Gets all libraries from a server
    /// - Parameter accessToken: Access token for the server
    /// - Returns: Libraries
    func getLibraries(accessToken: String) async throws -> [LibraryModel]
    /// Gets all media for a given library in chunks
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - libraryId: Library identifier
    ///   - index: Start of a chunk
    ///   - count: How much to request in a single request
    ///   - sortOrder: Ascending/descending
    ///   - sortBy: Metadata to sort by
    ///   - mediaTypes: Allowed media types from the server
    /// - Returns: Library media content
    func getLibraryMedia(
        accessToken: String,
        libraryId: String,
        index: Int,
        count: Int,
        sortOrder: LibraryMediaSortOrder,
        sortBy: LibraryMediaSortBy,
        mediaTypes: [MediaType]?
    ) async throws -> [MediaModel]
    /// Generates a URL for an image
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - imageType: Type of image (ex. poster)
    ///   - imageID: ID of the image
    ///   - width: Ideal width of the image
    /// - Returns: Formatted URL if possible
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, imageID: String, width: Int) -> URL?
    /// Generates a player for a media stream
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - contentID: The media source ID
    ///   - bitrate: Target bitrate
    ///   - subtitleID: Subtitles to be used (nil for none)
    ///   - audioID: Audio ID to be used
    ///   - videoID: Video ID to be used
    ///   - sessionID: A one-off token to not be reused when changing settings
    /// - Returns: Player ready for streaming
    func getStreamingContent(
        accessToken: String,
        contentID: String,
        bitrate: Int?,
        subtitleID: Int?,
        audioID: Int,
        videoID: Int,
        sessionID: String
    ) -> AVPlayerItem?
    /// Get all media data for a seasons
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - seasonID: ID of the season
    /// - Returns: Season data
    func getSeasonMedia(accessToken: String, seasonID: String) async throws -> [TVSeason]
    /// Updates the server about the current playback status
    /// - Parameters:
    ///   - itemID: Media ID of the currently played content
    ///   - mediaSourceID: Media source ID of the currently played content
    ///   - audioStreamIndex: Index for audio playback
    ///   - subtitleStreamIndex: Index for subtitle playback
    ///   - playbackPosition: Current playback position in ticks
    ///   - playSessionID: A one-off token to not be reused when changing settings
    ///   - userSessionID: User session ID provided by the server
    ///   - playbackStatus: Current state of playback (ex. paused, stopped, playing)
    ///   - accessToken: Access token provided by the server
    func updatePlaybackStatus(
        itemID: String,
        mediaSourceID: String,
        audioStreamIndex: Int,
        subtitleStreamIndex: Int?,
        playbackPosition: Int,
        playSessionID: String,
        userSessionID: String,
        playbackStatus: PlaybackStatus,
        accessToken: String
    ) async throws
}

public enum LibraryMediaSortOrder: String {
    case ascending = "Ascending"
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
    
    func request<T: Decodable>(
        verb: NetworkRequestType,
        path: String,
        headers: [String : String]? = nil,
        urlParams: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
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
            } catch {
                throw NetworkError.encodeJSONFailed(error)
            }
        }
        
        // Send the request
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetworkError.requestFailedToSend(error)
        }
        
        // Verify not invalid status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(responseCode: 0, response: "Not an HTTP response")
        }
        
        // Verify non-bad status code
        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.badResponse(
                responseCode: httpResponse.statusCode,
                response: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        
        // Decode the JSON response with more helpful errors
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
            return decodedResponse
        } catch let DecodingError.dataCorrupted(context) {
            throw NetworkError.decodeJSONFailed(DecodingError.dataCorrupted(context), url: url)
        } catch let DecodingError.keyNotFound(key, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.keyNotFound(key, context), url: url)
        } catch let DecodingError.valueNotFound(value, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.valueNotFound(value, context), url: url)
        } catch let DecodingError.typeMismatch(type, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.typeMismatch(type, context), url: url)
        } catch {
            throw NetworkError.decodeJSONFailed(error, url: url)
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
        let root: Root = try await network.request(
            verb: .get,
            path: "/Library/MediaFolders",
            headers: ["X-MediaBrowser-Token":accessToken],
            urlParams: nil,
            body: nil
        )
        return root.items
    }
    
    func getLibraryMedia(
        accessToken: String,
        libraryId: String,
        index: Int,
        count: Int,
        sortOrder: LibraryMediaSortOrder,
        sortBy: LibraryMediaSortBy,
        mediaTypes: [MediaType]?
    ) async throws -> [MediaModel] {
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
            URLQueryItem(name: "fields", value: "Genres"),
            URLQueryItem(name: "fields", value: "Overview"),
            URLQueryItem(name: "fields", value: "people"),
            URLQueryItem(name: "enableUserData", value: "true")
        ]
        
        for mediaType in mediaTypes ?? [] {
            params.append(URLQueryItem(name: "includeItemTypes", value: mediaType.rawValue))
        }
        
        let response: Root = try await network.request(
            verb: .get,
            path: "/Items",
            headers: ["X-MediaBrowser-Token":accessToken],
            urlParams: params,
            body: nil
        )
        try await withThrowingTaskGroup(of: (Int, [TVSeason]).self) { group in
            for (index, item) in response.items.enumerated() {
                switch item.mediaType {
                case .tv:
                    // Capture the id before creating the task
                    let itemId = item.id
                    group.addTask {
                        let seasons = try await self.getSeasonMedia(accessToken: accessToken, seasonID: itemId)
                        return (index, seasons)
                    }
                default:
                    break
                }
            }
            
            for try await (index, seasons) in group {
                response.items[index].mediaType = .tv(seasons)
            }
        }
        return response.items
    }
    
    func getSeasonMedia(accessToken: String, seasonID: String) async throws -> [TVSeason] {
        struct Root: Decodable {
            let items: [TVSeason]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                var seasonsContainer = try container.nestedUnkeyedContainer(forKey: .items)
                var tempSeasons: [TVSeason] = []
                var standInEpisodeNumber: Int = 0
                
                while !seasonsContainer.isAtEnd {
                    standInEpisodeNumber += 1
                    let episodeContainer = try seasonsContainer.nestedContainer(keyedBy: SeasonKeys.self)
                    let userDataContainer = try episodeContainer.nestedContainer(keyedBy: UserData.self, forKey: .userData)
                    
                    let episode: TVEpisode = TVEpisode(
                        id: try episodeContainer.decode(String.self, forKey: .id),
                        blurHashes: try episodeContainer.decodeIfPresent(MediaImageBlurHashes.self, forKey: .blurHashes),
                        title: try episodeContainer.decode(String.self, forKey: .title),
                        episodeNumber: try episodeContainer.decodeIfPresent(Int.self, forKey: .episodeNumber) ?? standInEpisodeNumber,
                        mediaSources: try episodeContainer.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? [],
                        lastPlayed: {
                            guard let dateString = try? userDataContainer.decodeIfPresent(
                                String.self,
                                forKey: .lastPlayedDate
                            ) else { return nil }
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            return formatter.date(from: dateString)
                        }(),
                        overview: try episodeContainer.decodeIfPresent(String.self, forKey: .episodeOverview),
                    )
                    let seasonID = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonID) ??
                    episodeContainer.decode(String.self, forKey: .seriesID)
                    
                    if let playbackTicks = try userDataContainer.decodeIfPresent(Int.self, forKey: .playbackPosition) {
                        for mediaSourceIndex in episode.mediaSources.indices {
                            episode.mediaSources[mediaSourceIndex].startTicks = playbackTicks
                        }
                    }
                    
                    if let seasonIndex = tempSeasons.firstIndex(where: { $0.id == seasonID }) { // Season already exists, append the episode
                        tempSeasons[seasonIndex].episodes.append(episode)
                    } else {
                        // New season, create it with the first episode
                        let newSeason = TVSeason(
                            id: seasonID,
                            title: try episodeContainer.decode(String.self, forKey: .seasonTitle),
                            episodes: [episode],
                            seasonNumber: try episodeContainer.decodeIfPresent(Int.self, forKey: .seasonNumber) ?? 1
                        )
                        tempSeasons.append(newSeason)
                    }
                }
                self.items = tempSeasons
            }
            
            private enum CodingKeys: String, CodingKey {
                case items = "Items"
            }
            
            private enum SeasonKeys: String, CodingKey {
                case title = "Name"
                case id = "Id"
                case episodeRuntimeTicks = "RunTimeTicks"
                case episodeNumber = "IndexNumber"
                case episodeOverview = "Overview"
                case seasonNumber = "ParentIndexNumber"
                case blurHashes = "ImageBlurHashes"
                case mediaSources = "MediaSources"
                case userData = "UserData"
                
                case seasonID = "SeasonId" // The actual season ID
                case seasonTitle = "SeasonName" // The actual season name
                case seriesID = "SeriesId" // Fallback for seasonID if SeasonId is missing
            }
            
            enum UserData: String, CodingKey {
                case lastPlayedDate = "LastPlayedDate"
                case playbackPosition = "PlaybackPositionTicks"
            }
        }
        
        let params : [URLQueryItem] = [
            URLQueryItem(name: "enableImages", value: "true"),
            URLQueryItem(name: "fields", value: "MediaSources"),
            URLQueryItem(name: "fields", value: "Overview")
        ]
        let response: Root = try await network.request(
            verb: .get,
            path: "/Shows/\(seasonID)/Episodes",
            headers: ["X-MediaBrowser-Token":accessToken],
            urlParams: params,
            body: nil
        )
        return response.items
    }
    
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, imageID: String, width: Int) -> URL? {
        let params : [URLQueryItem] = [
            URLQueryItem(name: "fillWidth", value: String(width)),
            URLQueryItem(name: "quality", value: "95")
        ]
        
        return network.buildURL(path: "/Items/\(imageID)/Images/\(imageType.rawValue)", urlParams: params)
    }
    
    func getStreamingContent(
        accessToken: String,
        contentID: String,
        bitrate: Int?,
        subtitleID: Int?,
        audioID: Int,
        videoID: Int,
        sessionID: String
    ) -> AVPlayerItem? {
        var params: [URLQueryItem] = [
            URLQueryItem(name: "playSessionID", value: sessionID),
            URLQueryItem(name: "mediaSourceID", value: contentID),
            URLQueryItem(name: "audioStreamIndex", value: String(audioID)),
            URLQueryItem(name: "videoStreamIndex", value: String(videoID)),
            // Let Jellyfin decide based on client capabilities
            URLQueryItem(name: "audioCodec", value: "aac,ac3,eac3,alac,mp3"),
            URLQueryItem(name: "videoCodec", value: "h264,hevc,vp9")
        ]
        
        if let bitrate = bitrate {
            params.append(URLQueryItem(name: "videoBitRate", value: String(bitrate)))
        }
        
        if let subtitleID = subtitleID {
            params.append(URLQueryItem(name: "SubtitleMethod", value: "Encode"))
            params.append(URLQueryItem(name: "subtitleStreamIndex", value: String(subtitleID)))
        }
        
        return network.buildAVPlayerItem(
            path: "/Videos/\(contentID)/main.m3u8",
            urlParams: params,
            headers: ["X-MediaBrowser-Token": accessToken]
        )
    }
    
    func updatePlaybackStatus(
        itemID: String,
        mediaSourceID: String,
        audioStreamIndex: Int,
        subtitleStreamIndex: Int?,
        playbackPosition: Int,
        playSessionID: String,
        userSessionID: String,
        playbackStatus: PlaybackStatus,
        accessToken: String
    ) async throws {
        struct PlaybackStatusStats: Encodable {
            let itemID: String
            let mediaSourceID: String
            let audioStreamIndex: Int
            let subtitleStreamIndex: Int
            let positionTicks: Int
            let playSessionID: String
            let userSessionID: String
            let isPaused: Bool
            
            enum CodingKeys: String, CodingKey {
                case itemID = "ItemId"
                case mediaSourceID = "MediaSourceId"
                case audioStreamIndex = "AudioStreamIndex"
                case subtitleStreamIndex = "SubtitleStreamIndex"
                case positionTicks = "PositionTicks"
                case playSessionID = "PlaySessionId"
                case userSessionID = "SessionId"
                case isPaused = "IsPaused"
            }
        }
        struct EmptyResponse: Decodable {}
        
        var isPaused = false
        let path: String
        switch playbackStatus {
        case .play:
            path = "Sessions/Playing"
        case .stop:
            path = "Sessions/Playing/Stopped"
        case .progressed:
            path = "Sessions/Playing/Progress"
        case .paused:
            path = "Sessions/Playing/Progress"
            isPaused = true
        }
        
        let stats: PlaybackStatusStats = PlaybackStatusStats(
            itemID: itemID,
            mediaSourceID: mediaSourceID,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex ?? -1,
            positionTicks: playbackPosition,
            playSessionID: playSessionID,
            userSessionID: userSessionID,
            isPaused: isPaused,
        )
        
        let _: EmptyResponse = try await network.request(
            verb: .post,
            path: path,
            headers: ["X-MediaBrowser-Token": accessToken],
            urlParams: nil,
            body: stats
        )
    }
}

/// Denotes playback status of a player
public enum PlaybackStatus {
    /// The player is currently playing
    case play
    /// The player is currently stopped and will not resume
    case stop
    /// The player has made some progress
    case progressed
    /// The player is temporarily paused
    case paused
}
