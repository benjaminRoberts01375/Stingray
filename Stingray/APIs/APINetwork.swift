//
//  APINetwork.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit
import SwiftUI

/// Defines a network that is reliant on primitives already created by `BasicNetworkProtocol`
public protocol AdvancedNetworkProtocol {
    /// Log-in a user via a username and password
    /// - Parameters:
    ///   - username: User's username
    ///   - password: User's password
    /// - Returns: Credentials and user data from server
    func login(username: String, password: String) async throws(AccountErrors) -> APILoginResponse
    /// Gets all libraries from a server
    /// - Parameter accessToken: Access token for the server
    /// - Parameter userID: ID of the user to get libraries for
    /// - Returns: Libraries
    func getLibraries(accessToken: String, userID: String) async throws(LibraryErrors) -> [LibraryModel]
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
    ) async throws(LibraryErrors) -> [MediaModel]
    /// Generates a URL for an image
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - imageType: Type of image (ex. poster)
    ///   - mediaID: ID of the image
    ///   - width: Ideal width of the image
    /// - Returns: Formatted URL if possible
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL?
    /// Generates a player for a media stream
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - contentID: The media source ID
    ///   - bitrate: Target video bitrate in bits per second
    ///   - subtitleID: Subtitles to be used (nil for none)
    ///   - audioID: Audio ID to be used
    ///   - videoID: Video ID to be used
    ///   - sessionID: A one-off token to not be reused when changing settings
    ///   - title: Main title of the content to be shown
    ///   - subtitle: An optional descriptor of the content (ex. season 2, episode 4)
    /// - Returns: Player ready for streaming
    func getStreamingContent(
        accessToken: String,
        contentID: String,
        bitrate: Int,
        subtitleID: String?,
        audioID: String,
        videoID: String,
        sessionID: String,
        title: String,
        subtitle: String?
    ) -> AVPlayerItem?
    /// Get all media data for a seasons
    /// - Parameters:
    ///   - accessToken: Access token for the server
    ///   - seasonID: ID of the season
    /// - Returns: Season data
    func getSeasonMedia(accessToken: String, seasonID: String) async throws(LibraryErrors) -> [TVSeason]
    /// Updates the server about the current playback status
    /// - Parameters:
    ///   - mediaSourceID: Media source ID of the currently played content
    ///   - audioStreamIndex: Index for audio playback
    ///   - subtitleStreamIndex: Index for subtitle playback
    ///   - playbackPosition: Current playback position in ticks
    ///   - playSessionID: A one-off token to not be reused when changing settings
    ///   - userSessionID: User session ID provided by the server
    ///   - playbackStatus: Current state of playback (ex. paused, stopped, playing)
    ///   - accessToken: Access token provided by the server
    func updatePlaybackStatus(
        mediaSourceID: String,
        audioStreamIndex: String,
        subtitleStreamIndex: String?,
        playbackPosition: Int,
        playSessionID: String,
        userSessionID: String,
        playbackStatus: PlaybackStatus,
        accessToken: String
    ) async throws
    
    /// Retrieve recently added media of some type
    /// - Parameters:
    ///   - contentType: Type of media to retrieve
    ///   - accessToken: Access token for the server
    /// - Returns: A silm verion of the media type
    func getRecentlyAdded(contentType: RecentlyAddedMediaType, accessToken: String) async throws(AdvancedNetworkErrors) -> [SlimMedia]
    
    /// Gets up next shows
    /// - Parameter accessToken: Access token for the server
    /// - Returns: Available media for up next
    func getUpNext(accessToken: String) async throws(AdvancedNetworkErrors) -> [SlimMedia]
    /// Generates a URL to get the user's profile image
    /// - Parameters:
    ///   - userID: ID of the user
    /// - Returns: Formatted URL
    func getUserImageURL(userID: String) -> URL?
    /// Loads special features for a given media ID.
    /// - Parameters:
    ///   - mediaID: ID of media to gather special features for
    ///   - accessToken: Access token for the server
    /// - Returns: Special features
    func loadSpecialFeatures(mediaID: String, accessToken: String) async throws(AdvancedNetworkErrors) -> [SpecialFeature]
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

public struct APILoginResponse: Decodable {
    let userName: String
    let sessionId: String
    let userId: String
    let accessToken: String
    let serverId: String
    var serverVersion: String?
    
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
    
    public init(from decoder: Decoder) throws(JSONError) {
        do {
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
            
            serverVersion = nil
        }
        catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "APILoginResponse") }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "APILoginResponse") }
            else { throw JSONError.failedJSONDecode("APILoginResponse", DecodingError.valueNotFound(Any.self, context)) }
        }
        catch { throw JSONError.failedJSONDecode("APILoginResponse", error) }
    }
}

final class JellyfinAdvancedNetwork: AdvancedNetworkProtocol {
    var network: BasicNetworkProtocol
    
    init(network: BasicNetworkProtocol) {
        self.network = network
    }
    
    /// Gets the current version of the Jellyfin server
    /// - Parameter accessToken: User's access token for the Jellyfin server.
    /// - Returns: The version of the server in this format: `xx.xx.xx` with no "v" at the start, and the name of the server.
    func getServerVersion(accessToken: String) async throws(AccountErrors) -> (String, String) {
        struct Root: Decodable {
            let Version: String
            let ServerName: String
        }
        
        do {
            let root: Root = try await network.request(
                verb: .get,
                path: "/System/Info",
                headers: ["X-MediaBrowser-Token": accessToken],
                urlParams: nil,
                body: nil
            )
            
            return (root.Version, root.ServerName)
        } catch {
            throw AccountErrors.serverVersionFailed(error)
        }
    }
    
    func login(username: String, password: String) async throws(AccountErrors) -> APILoginResponse {
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
        
        do {
            return try await network.request(
                verb: .post,
                path: "/Users/AuthenticateByName",
                headers: nil,
                urlParams: nil,
                body: requestBody
            )
        } catch {
            throw AccountErrors.loginFailed(error)
        }
    }
    
    func getLibraries(accessToken: String, userID: String) async throws(LibraryErrors) -> [LibraryModel] {
        struct Root: Decodable {
            let items: [LibraryModel]
            
            enum CodingKeys: String, CodingKey {
                case items = "Items"
            }
        }
        do {
            let root: Root = try await network.request(
                verb: .get,
                path: "/Users/\(userID)/Views",
                headers: ["X-MediaBrowser-Token":accessToken],
                urlParams: nil,
                body: nil
            )
            return root.items
        } catch let error { throw LibraryErrors.gettingLibraries(error) }
    }
    
    func getLibraryMedia(
        accessToken: String,
        libraryId: String,
        index: Int,
        count: Int,
        sortOrder: LibraryMediaSortOrder,
        sortBy: LibraryMediaSortBy,
        mediaTypes: [MediaType]?
    ) async throws(LibraryErrors) -> [MediaModel] {
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
        
        do {
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
                do {
                    for try await (index, seasons) in group {
                        response.items[index].mediaType = .tv(seasons)
                    }
                } catch let error as RError { throw LibraryErrors.gettingSeasons(error, libraryId) }
            }
            return response.items
        }
        catch let error as RError { throw LibraryErrors.gettingLibraryMedia(error, libraryId) }
        catch { throw LibraryErrors.unknown(libraryId) }
    }
    
    func getSeasonMedia(accessToken: String, seasonID: String) async throws(LibraryErrors) -> [TVSeason] {
        struct Root: Decodable {
            let items: [TVSeason]
            
            init(from decoder: Decoder) throws(JSONError) {
                do {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    var seasonsContainer = try container.nestedUnkeyedContainer(forKey: .items)
                    var tempSeasons: [TVSeason] = []
                    var standInEpisodeNumber: Int = 0
                    var lastSeasonID: String = ""
                    
                    while !seasonsContainer.isAtEnd {
                        standInEpisodeNumber += 1 // Fallback season number if it's not present
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
                                episode.mediaSources[mediaSourceIndex].startPoint = TimeInterval(ticks: playbackTicks)
                            }
                        }
                        
                        let seasonTitle = try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season"
                        if seasonTitle == "Specials" { // Episode is a special
                            let newSeason = TVSeason(
                                title: "Special",
                                episodes: [episode]
                            )
                            tempSeasons.append(newSeason)
                        }
                        else if seasonID == lastSeasonID && tempSeasons.last?.title == "Special" { // Season was split by specials
                            lastSeasonID = seasonID
                            let newSeason = TVSeason(
                                title: (try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season") +
                                " Cont.",
                                episodes: [episode],
                            )
                            tempSeasons.append(newSeason)
                        }
                        else if seasonID == lastSeasonID, let lastSeason = tempSeasons.last { // Episode is in the last season
                            lastSeason.episodes.append(episode)
                        }
                        else { // Episode needs a new season
                            lastSeasonID = seasonID
                            let newSeason = TVSeason(
                                title: try episodeContainer.decodeIfPresent(String.self, forKey: .seasonTitle) ?? "Unknown Season",
                                episodes: [episode],
                            )
                            tempSeasons.append(newSeason)
                        }
                    }
                    self.items = tempSeasons
                }
                catch DecodingError.keyNotFound(let key, _) { throw JSONError.missingKey(key.stringValue, "Root") }
                catch DecodingError.valueNotFound(_, let context) {
                    if let key = context.codingPath.last { throw JSONError.missingContainer(key.stringValue, "Root") }
                    else { throw JSONError.failedJSONDecode("Season Media", DecodingError.valueNotFound(Any.self, context)) }
                }
                catch { throw JSONError.failedJSONDecode("Season Media", error) }
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
            URLQueryItem(name: "fields", value: "Overview"),
            URLQueryItem(name: "sortBy", value: "AiredEpisodeOrder")
        ]
        do {
            let response: Root = try await network.request(
                verb: .get,
                path: "/Shows/\(seasonID)/Episodes",
                headers: ["X-MediaBrowser-Token":accessToken],
                urlParams: params,
                body: nil
            )
            return response.items
        }
        catch let error as RError { throw LibraryErrors.gettingSeason(error, seasonID) }
    }
    
    func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        let params : [URLQueryItem] = [
            URLQueryItem(name: "fillWidth", value: String(width)),
            URLQueryItem(name: "quality", value: "95")
        ]
        
        return network.buildURL(path: "/Items/\(mediaID)/Images/\(imageType.rawValue)", urlParams: params)
    }
    
    func buildAVPlayerItem(path: String, urlParams: [URLQueryItem]?, headers: [String : String]?) -> AVPlayerItem? {
        guard let url = network.buildURL(path: path, urlParams: urlParams) else { return nil }
        // Configure asset options with proper HTTP headers
        var options: [String: Any] = [:]
        if let headers = headers {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        
        let asset = AVURLAsset(url: url, options: options)
        return AVPlayerItem(asset: asset)
    }
    
    func getStreamingContent(
        accessToken: String,
        contentID: String,
        bitrate: Int,
        subtitleID: String?,
        audioID: String,
        videoID: String,
        sessionID: String,
        title: String,
        subtitle: String?
    ) -> AVPlayerItem? {
        var params: [URLQueryItem] = [
            // Media selection
            URLQueryItem(name: "playSessionID", value: sessionID),
            URLQueryItem(name: "mediaSourceID", value: contentID),
            URLQueryItem(name: "audioStreamIndex", value: String(audioID)),
            URLQueryItem(name: "videoStreamIndex", value: String(videoID)),
            
            // Video config
            URLQueryItem(name: "videoBitRate", value: String(bitrate)),
            URLQueryItem(name: "videoCodec", value: "hevc,h264"),
            URLQueryItem(name: "container", value: "mp4"),
            URLQueryItem(name: "transcodingContainer", value: "mp4"),
            URLQueryItem(name: "allowVideoStreamCopy", value: "true"),
            URLQueryItem(name: "hevc-videobitdepth", value: "10"),
            URLQueryItem(name: "hevc-rangetype", value: "SDR,HDR10,HDR10Plus,DOVI,DOVIWithHDR10,DOVIWithSDR,DOVIWithHDR10Plus"),
            URLQueryItem(name: "hevc-level", value: "153"),
            URLQueryItem(name: "hevc-profile", value: "main10"),
            URLQueryItem(name: "hevc-codectag", value: "hvc1,dvh1"),
            URLQueryItem(name: "deInterlace", value: "true"),
            URLQueryItem(name: "h265-codectag", value: "hvc1,dvh1,dvhe"),
            
            // Audio config
            URLQueryItem(name: "audioCodec", value: "aac,ac3,eac3,alac,mp3"),
            URLQueryItem(name: "allowAudioStreamCopy", value: "true"),
            URLQueryItem(name: "enableAudioVbrEncoding", value: "true"),
            
            // Streaming config
            URLQueryItem(name: "breakOnNonKeyFrames", value: "true"),
            URLQueryItem(name: "requireAVC", value: "false"),
            URLQueryItem(name: "segmentContainer", value: "mp4"),
            URLQueryItem(name: "copyTimestamps", value: "true"),
            URLQueryItem(name: "enableAutoStreamCopy", value: "true")
        ]
        
        if let subtitleID = subtitleID {
            params.append(URLQueryItem(name: "SubtitleMethod", value: "Encode"))
            params.append(URLQueryItem(name: "subtitleStreamIndex", value: String(subtitleID)))
        }
        
        guard let item = self.buildAVPlayerItem(
            path: "/Videos/\(contentID)/main.m3u8",
            urlParams: params,
            headers: ["X-MediaBrowser-Token": accessToken]
        ) else { return nil }
        
        // Set the title metadata
        let titleMetadata = AVMutableMetadataItem()
        titleMetadata.identifier = .commonIdentifierTitle
        titleMetadata.value = title as NSString
        titleMetadata.extendedLanguageTag = "und"
        
        // Set the subtitle/description metadata
        let subtitleMetadata = AVMutableMetadataItem()
        subtitleMetadata.identifier = .iTunesMetadataTrackSubTitle
        subtitleMetadata.value = (subtitle ?? "") as NSString
        subtitleMetadata.extendedLanguageTag = "und"
        
        item.externalMetadata = [titleMetadata, subtitleMetadata]
        
        return item
    }
    
    func updatePlaybackStatus(
        mediaSourceID: String,
        audioStreamIndex: String,
        subtitleStreamIndex: String?,
        playbackPosition: Int,
        playSessionID: String,
        userSessionID: String,
        playbackStatus: PlaybackStatus,
        accessToken: String
    ) async throws(JellyfinNetworkErrors) {
        struct PlaybackStatusStats: Encodable {
            let itemID: String
            let mediaSourceID: String
            let audioStreamIndex: String
            let subtitleStreamIndex: String
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
            itemID: mediaSourceID,
            mediaSourceID: mediaSourceID,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex ?? "-1",
            positionTicks: playbackPosition,
            playSessionID: playSessionID,
            userSessionID: userSessionID,
            isPaused: isPaused,
        )
        
        do {
            let _: EmptyResponse = try await network.request(
                verb: .post,
                path: path,
                headers: ["X-MediaBrowser-Token": accessToken],
                urlParams: nil,
                body: stats
            )
        } catch { throw JellyfinNetworkErrors.playbackUpdateFailed(error) }
    }
    
    func getRecentlyAdded(contentType: RecentlyAddedMediaType, accessToken: String) async throws(AdvancedNetworkErrors) -> [SlimMedia] {
        var params: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(25)"),
            URLQueryItem(name: "fields", value: "ParentId")
        ]
        
        switch contentType {
        case .all:
            break
        case .movie:
            params.append(URLQueryItem(name: "includeItemTypes", value: "Movie"))
        case .tv:
            params.append(URLQueryItem(name: "includeItemTypes", value: "Series"))
        }
        
        do {
            return try await network.request(
                verb: .get,
                path: "/Items/Latest",
                headers: ["X-MediaBrowser-Token": accessToken],
                urlParams: params,
                body: nil
            )
        } catch {
            throw AdvancedNetworkErrors.failedRecentlyAdded(error)
        }
    }
    
    func getUpNext(accessToken: String) async throws(AdvancedNetworkErrors) -> [SlimMedia] {
        struct Root: Decodable {
            let Items: [SlimMedia]
        }
        
        let params: [URLQueryItem] = [ URLQueryItem(name: "fields", value: "ParentId") ]
        
        do {
            let root: Root = try await network.request(
                verb: .get,
                path: "/Shows/NextUp",
                headers: ["X-MediaBrowser-Token": accessToken],
                urlParams: params,
                body: nil
            )
            return root.Items
        } catch {
            throw AdvancedNetworkErrors.failedRecentlyAdded(error)
        }
    }
    
    func getUserImageURL(userID: String) -> URL? {
        let params: [URLQueryItem] = [
            URLQueryItem(name: "userID", value: userID)
        ]
        
        return network.buildURL(path: "/UserImage", urlParams: params)
    }
    
    public func loadSpecialFeatures(mediaID: String, accessToken: String) async throws(AdvancedNetworkErrors) -> [SpecialFeature] {
        do {
            return try await network.request(
                verb: .get,
                path: "/Items/\(mediaID)/SpecialFeatures",
                headers: ["X-MediaBrowser-Token": accessToken],
                urlParams: nil,
                body: nil
            )
        } catch { throw AdvancedNetworkErrors.failedSpecialFeatures(error) }
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
