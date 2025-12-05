//
//  JellyfinModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit

protocol StreamingServiceProtocol {
    func login(username: String, password: String) async throws
    func getLibraries() async throws -> [LibraryModel]
    func getStreamingContent(mediaSource: any MediaSourceProtocol, subtitleID: Int?, audioID: Int, videoID: Int) -> AVPlayerItem?
    func getImageURL(imageType: MediaImageType, imageID: String, width: Int) -> URL?
    func getLibraryMedia(libraryID: String, index: Int, count: Int, sortOrder: LibraryMediaSortOrder, sortBy: LibraryMediaSortBy) async throws -> [MediaModel]
}

final class JellyfinModel: StreamingServiceProtocol {
    var networkAPI: AdvancedNetworkProtocol
    var storageAPI: AdvancedStorageProtocol
    
    var url: URL? {
        didSet { storageAPI.setServerURL(url) }
    }
    
    var usersName: String? {
        didSet { storageAPI.setUsersName(usersName) }
    }
    
    var usersID: String? {
        didSet { storageAPI.setUserID(usersID) }
    }
    
    var sessionID: String? {
        didSet { storageAPI.setSessionID(sessionID) }
    }
    
    var accessToken: String {
        didSet { storageAPI.setAccessToken(accessToken)}
    }
    
    var serverID: String? {
        didSet { storageAPI.setServerID(serverID) }
    }
    
    init(address: URL?) throws {
        enum AddressError: Error {
            case badAddress
        }
        
        guard let address = address else { throw AddressError.badAddress }
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: address))
        let storageAPI = DefaultsAdvancedStorage(storage: DefaultsBasicStorage())
        self.storageAPI = storageAPI
        self.url = address
        self.usersName = storageAPI.getUsersName()
        self.usersID = storageAPI.getUserID()
        self.sessionID = storageAPI.getSessionID()
        self.accessToken = storageAPI.getAccessToken() ?? ""
        self.serverID = storageAPI.getServerID()
        print("URL: \(url?.absoluteString  ?? "None available")")
        print("User's Name: \(usersName ?? "None available")")
        print("UserID: \(usersID ?? "None available")")
        print("SessionID: \(sessionID ?? "None available")")
        print("Access Token: \(accessToken)")
        print("ServerID: \(serverID ?? "None available")")
    }
    
    func login(username: String, password: String) async throws {
        let response = try await networkAPI.login(username: username, password: password)
        self.usersName = response.userName
        self.usersID = response.userId
        self.sessionID = response.sessionId
        self.accessToken = response.accessToken
        self.serverID = response.serverId
    }
    
    func getLibraries() async throws -> [LibraryModel] {
        return try await networkAPI.getLibraries(accessToken: accessToken)
    }
    
    func getStreamingContent(mediaSource: any MediaSourceProtocol, subtitleID: Int?, audioID: Int, videoID: Int) -> AVPlayerItem? {
        let sessionID = UUID().uuidString
        return networkAPI.getStreamingContent(accessToken: accessToken, contentID: mediaSource.id, bitrate: mediaSource.videoStreams[0].bitrate, subtitleID: subtitleID, audioID: audioID, videoID: videoID, sessionID: sessionID)
    }
    
    func getSeasonMedia(seasonID: String) async throws -> [TVSeason] {
        return try await networkAPI.getSeasonMedia(accessToken: accessToken, seasonID: seasonID)
    }
    
    func getImageURL(imageType: MediaImageType, imageID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, imageID: imageID, width: width)
    }
    
    func getLibraryMedia(libraryID: String, index: Int, count: Int, sortOrder: LibraryMediaSortOrder, sortBy: LibraryMediaSortBy) async throws -> [MediaModel] {
        return try await networkAPI.getLibraryMedia(
            accessToken: accessToken,
            libraryId: libraryID,
            index: index,
            count: count,
            sortOrder: .Ascending,
            sortBy: .SortName,
            mediaTypes: [.movies([]), .tv(nil)]
        )
    }
}
