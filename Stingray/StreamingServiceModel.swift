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
    func playbackStart(mediaID: String, mediaSource: any MediaSourceProtocol, videoID: Int, audioID: Int, subtitleID: Int?) -> AVPlayer?
    func playbackEnd()
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
    
    var playerProgress: JellyfinPlayerProgress?
    
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
    
    func playbackStart(mediaID: String, mediaSource: any MediaSourceProtocol, videoID: Int, audioID: Int, subtitleID: Int?) -> AVPlayer? {
        let sessionID = UUID().uuidString
        guard let videoStream = mediaSource.videoStreams.first(where: { $0.id == videoID } ),
              let playerItem = networkAPI.getStreamingContent(
                accessToken: accessToken,
                contentID: mediaSource.id,
                bitrate: videoStream.bitrate,
                subtitleID: subtitleID,
                audioID: audioID,
                videoID: videoID,
                sessionID: sessionID
              )
        else { return nil }
        let player = AVPlayer(playerItem: playerItem)
        
        self.playerProgress = JellyfinPlayerProgress(
            player: player,
            network: networkAPI,
            mediaID: mediaID,
            mediaSourceID: mediaSource.id,
            videoID: videoID,
            audioID: audioID,
            subtitleID: subtitleID,
            playbackSessionID: sessionID,
            userSessionID: self.sessionID ?? "",
            accessToken: self.accessToken
        )
        self.playerProgress?.start()
        
        return player
    }
    
    func playbackEnd() {
        self.playerProgress?.stop()
        self.playerProgress = nil
    }
}

final class JellyfinPlayerProgress {
    private let player: AVPlayer
    private let network: any AdvancedNetworkProtocol
    private var timer: Timer?
    private let mediaID: String
    private let mediaSourceID: String
    private let videoID: Int
    private let audioID: Int
    private let subtitleID: Int?
    private let playbackSessionID: String
    private let userSessionID: String
    private let accessToken: String
    
    init(player: AVPlayer, network: any AdvancedNetworkProtocol, mediaID: String, mediaSourceID: String, videoID: Int, audioID: Int, subtitleID: Int?, playbackSessionID: String, userSessionID: String, accessToken: String) {
        self.player = player
        self.network = network
        self.mediaID = mediaID
        self.mediaSourceID = mediaSourceID
        self.videoID = videoID
        self.audioID = audioID
        self.subtitleID = subtitleID
        self.timer = nil
        self.playbackSessionID = playbackSessionID
        self.userSessionID = userSessionID
        self.accessToken = accessToken
        
        Task {
            do {
                try await self.network.updatePlaybackStatus(
                    itemID: self.mediaID,
                    mediaSourceID: self.mediaSourceID,
                    audioStreamIndex: self.audioID,
                    subtitleStreamIndex: self.subtitleID,
                    playbackPosition: Int(self.player.currentTime().seconds * 10_000_000),
                    playSessionID: self.playbackSessionID,
                    userSessionID: self.userSessionID,
                    playbackStatus: .play,
                    accessToken: self.accessToken
                )
            } catch { }
        }
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func start() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    let playbackStatus: PlaybackStatus
                    switch self.player.timeControlStatus {
                    case .playing:
                        playbackStatus = .progressed
                    default:
                        playbackStatus = .paused
                    }
                    try await self.network.updatePlaybackStatus(
                        itemID: self.mediaID,
                        mediaSourceID: self.mediaSourceID,
                        audioStreamIndex: self.audioID,
                        subtitleStreamIndex: self.subtitleID,
                        playbackPosition: Int(self.player.currentTime().seconds * 10_000_000),
                        playSessionID: self.playbackSessionID,
                        userSessionID: self.userSessionID,
                        playbackStatus: playbackStatus,
                        accessToken: self.accessToken
                    )
                } catch { }
            }
        }
    }
    
    func stop() {
        Task {
            do {
                try await self.network.updatePlaybackStatus(
                    itemID: self.mediaID,
                    mediaSourceID: self.mediaSourceID,
                    audioStreamIndex: self.audioID,
                    subtitleStreamIndex: self.subtitleID,
                    playbackPosition: Int(self.player.currentTime().seconds * 10_000_000),
                    playSessionID: self.playbackSessionID,
                    userSessionID: self.userSessionID,
                    playbackStatus: .stop,
                    accessToken: self.accessToken
                )
            } catch { }
        }
    }
}
