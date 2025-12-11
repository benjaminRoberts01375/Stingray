//
//  JellyfinModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit

protocol StreamingServiceProtocol: StreamingServiceBasicProtocol {
    var libraryStatus: LibraryStatus { get }
    
    func login(username: String, password: String) async throws
    func retrieveLibraries() async
    func playbackStart(mediaSource: any MediaSourceProtocol, videoID: Int, audioID: Int, subtitleID: Int?) -> AVPlayer?
    func playbackEnd()
    func getImageURL(imageType: MediaImageType, imageID: String, width: Int) -> URL?
    func lookup(mediaID: String, parentID: String) -> MediaLookupStatus
}

enum LibraryStatus {
    case waiting
    case retrieving
    case available([LibraryModel])
    case complete([LibraryModel])
    case error(Error)
}

/// Denotes the availablity of a piece of media
enum MediaLookupStatus {
    /// The requested media was found
    case found(any MediaProtocol)
    /// The requested media was not found, but may be available once libraries finish downloading
    case temporarilyNotFound
    /// The requested media was not found despite all libraries being downloaded
    case notFound
}

@Observable
final class JellyfinModel: StreamingServiceProtocol {
    var networkAPI: AdvancedNetworkProtocol
    var storageAPI: AdvancedStorageProtocol
    var libraryStatus: LibraryStatus
    
    var url: URL {
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
    
    init(address: URL) throws {
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: address))
        let storageAPI = DefaultsAdvancedStorage(storage: DefaultsBasicStorage())
        self.storageAPI = storageAPI
        self.url = address
        self.usersName = storageAPI.getUsersName()
        self.usersID = storageAPI.getUserID()
        self.sessionID = storageAPI.getSessionID()
        self.accessToken = storageAPI.getAccessToken() ?? ""
        self.serverID = storageAPI.getServerID()
        self.libraryStatus = .waiting
        
        // Manually call storage setters during init since didSet won't always trigger >:(
        storageAPI.setServerURL(address)
        storageAPI.setUsersName(self.usersName)
        storageAPI.setUserID(self.usersID)
        storageAPI.setSessionID(self.sessionID)
        storageAPI.setAccessToken(self.accessToken)
        storageAPI.setServerID(self.serverID)
        
        print("URL: \(url.absoluteString)")
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
    
    func retrieveLibraries() async {
        let batchSize = 50
        
        do {
            self.libraryStatus = .retrieving
            let libraries = try await networkAPI.getLibraries(accessToken: accessToken)
            self.libraryStatus = .available(libraries)
            try await withThrowingTaskGroup(of: Void.self) { group in
                try await Task.sleep(for: .seconds(7))
                for library in libraries {
                    group.addTask {
                        var currentIndex = 0
                        var allMedia: [MediaModel] = []
                        if case .available(let existingMedia) = await library.media {
                            allMedia = existingMedia
                        }
                        
                        while true {
                            let incomingMedia = try await self.networkAPI.getLibraryMedia(
                                accessToken: self.accessToken,
                                libraryId: library.id,
                                index: currentIndex,
                                count: batchSize,
                                sortOrder: .ascending,
                                sortBy: .SortName,
                                mediaTypes: [.movies([]), .tv(nil)]
                            )
                            
                            allMedia.append(contentsOf: incomingMedia)
                            
                            // Update the UI after each batch
                            await MainActor.run { [allMedia] in
                                library.media = .available(allMedia)
                            }
                            
                            // If we received fewer items than requested, we've reached the end
                            if incomingMedia.count < batchSize {
                                await MainActor.run { [allMedia] in
                                    library.media = .complete(allMedia)
                                }
                                break
                            }
                            
                            currentIndex += batchSize
                        }
                    }
                }
                try await group.waitForAll()
                self.libraryStatus = .complete(libraries)
            }
        } catch {
            self.libraryStatus = .error(error)
        }
    }
    
    func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [SlimMedia] {
        do {
            return try await networkAPI.getRecentlyAdded(contentType: contentType, accessToken: accessToken)
        } catch { return [] }
    }
    
    func retrieveUpNext() async -> [SlimMedia] {
        do {
            return try await networkAPI.getUpNext(accessToken: accessToken)
        } catch {
            print("Up next failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func lookup(mediaID: String, parentID: String) -> MediaLookupStatus {
        let libraries: [LibraryModel]
        switch self.libraryStatus {
        case .available(let libs), .complete(let libs):
            libraries = libs
        default:
            return .temporarilyNotFound
        }
        
        // Check the parent library first (most likely location)
        if let parentLibrary = libraries.first(where: { $0.id == parentID }) {
            let allMedia: [MediaModel]?
            switch parentLibrary.media {
            case .available(let media), .complete(let media):
                allMedia = media
            default:
                allMedia = nil
            }
            
            if let allMedia = allMedia,
               let found = allMedia.first(where: { $0.id == mediaID }) {
                return .found(found)
            }
        }
        
        // Fallback: search all libraries
        for library in libraries {
            let allMedia: [MediaModel]?
            switch library.media {
            case .available(let media), .complete(let media):
                allMedia = media
            default:
                allMedia = nil
            }
            
            if let allMedia = allMedia,
               let found = allMedia.first(where: { $0.id == mediaID }) {
                return .found(found)
            }
        }
        switch self.libraryStatus {
        case .complete:
            return .notFound
        default:
            return .temporarilyNotFound
        }
    }
    
    func getSeasonMedia(seasonID: String) async throws -> [TVSeason] {
        return try await networkAPI.getSeasonMedia(accessToken: accessToken, seasonID: seasonID)
    }
    
    func getImageURL(imageType: MediaImageType, imageID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, imageID: imageID, width: width)
    }
    
    func playbackStart(mediaSource: any MediaSourceProtocol, videoID: Int, audioID: Int, subtitleID: Int?) -> AVPlayer? {
        let sessionID = UUID().uuidString
        guard let videoStream = mediaSource.videoStreams.first(where: { $0.id == videoID }),
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
            mediaID: mediaSource.id,
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
    
    init(
        player: AVPlayer,
        network: any AdvancedNetworkProtocol,
        mediaID: String,
        mediaSourceID: String,
        videoID: Int,
        audioID: Int,
        subtitleID: Int?,
        playbackSessionID: String,
        userSessionID: String,
        accessToken: String
    ) {
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
