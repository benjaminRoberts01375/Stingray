//
//  JellyfinModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit

protocol StreamingServiceProtocol: StreamingServiceBasicProtocol {
    var libraryStatus: LibraryStatus { get }
    var usersName: String { get }
    var userID: String { get }
    var serviceURL: URL { get }
    var playerProgress: PlayerProtocol? { get }
    
    func retrieveLibraries() async
    func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Bitrate,
        title: String,
        subtitle: String?
    ) -> AVPlayer?
    func playbackEnd()
    func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus
}

/// Describes the current setup status for a downloaded library
enum LibraryStatus {
    /// The library object has been created but hasn't fetched
    case waiting
    /// The library object has been created and is fetching
    case retrieving
    /// Some of the library's content is available, but we're still fetching
    case available([LibraryModel])
    /// All of this library's content has been downloaded
    case complete([LibraryModel])
    /// The library has errored out
    case error(Error)
}

/// Denotes the availablity of a piece of media
public enum MediaLookupStatus {
    /// The requested media was found
    case found(any MediaProtocol)
    /// The requested media was not found, but may be available once libraries finish downloading
    case temporarilyNotFound
    /// The requested media was not found despite all libraries being downloaded
    case notFound
}

/// Types of used bitrates
public enum Bitrate {
    /// The maximum allowed bitrate
    case full
    /// An artifical limit on the bitrate
    case limited(Int)
}

@Observable
public final class JellyfinModel: StreamingServiceProtocol {
    var networkAPI: AdvancedNetworkProtocol
    var libraryStatus: LibraryStatus
    
    var usersName: String
    var userID: String
    var sessionID: String
    var accessToken: String
    var serverID: String
    var serviceURL: URL
    var playerProgress: PlayerProtocol?
    
    public init(
        userDisplayName: String,
        userID: String,
        serviceID: String,
        accessToken: String,
        sessionID: String,
        serviceURL: URL
    ) {
        // APIs
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        
        // Misc properties
        self.libraryStatus = .waiting
        self.usersName = userDisplayName
        self.userID = userID
        self.serverID = serviceID
        self.accessToken = accessToken
        self.sessionID = sessionID
        self.serviceURL = serviceURL
    }
    
    private init(response: APILoginResponse, serviceURL: URL) {
        // APIs
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        
        // Properties
        self.usersName = response.userName
        self.userID = response.userId
        self.sessionID = response.sessionId
        self.accessToken = response.accessToken
        self.serverID = response.serverId
        self.libraryStatus = .waiting
        self.serviceURL = serviceURL
    }
    
    static func login(url: URL, username: String, password: String) async throws -> JellyfinModel {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: url))
        let response = try await networkAPI.login(username: username, password: password)
        let userModel = UserModel()
        userModel.addUser(
            User(
                serviceURL: url,
                serviceType: .Jellyfin(
                    UserJellyfin(accessToken: response.accessToken, sessionID: response.sessionId)
                ),
                serviceID: response.serverId,
                id: response.userId,
                displayName: response.userName
            )
        )
        userModel.setDefaultUser(userID: response.userId)
        return JellyfinModel(response: response, serviceURL: url)
    }
    
    func retrieveLibraries() async {
        let batchSize = 50
        
        do {
            self.libraryStatus = .retrieving
            
            let libraries =
            try await networkAPI.getLibraries(accessToken: self.accessToken, userID: self.userID)
                .filter { $0.libraryType != "boxsets" } // Temp fix until we support collections
            
            self.libraryStatus = .available(libraries)
            try await withThrowingTaskGroup(of: Void.self) { group in
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
    
    public func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [SlimMedia] {
        do {
            return try await networkAPI.getRecentlyAdded(contentType: contentType, accessToken: accessToken)
        } catch { return [] }
    }
    
    public func retrieveUpNext() async -> [SlimMedia] {
        do {
            return try await networkAPI.getUpNext(accessToken: accessToken)
        } catch {
            print("Up next failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus {
        let libraries: [LibraryModel]
        switch self.libraryStatus {
        case .available(let libs), .complete(let libs):
            libraries = libs
        default:
            return .temporarilyNotFound
        }
        
        // Check the parent library first (most likely location)
        if let parentID = parentID,
           let parentLibrary = libraries.first(where: { $0.id == parentID }) {
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
    
    public func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, mediaID: mediaID, width: width)
    }
    
    func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Bitrate,
        title: String,
        subtitle: String?
    ) -> AVPlayer? {
        let sessionID = UUID().uuidString
        guard let videoStream = mediaSource.videoStreams.first(where: { $0.id == videoID }) else { return nil }
        let bitrateBits = switch bitrate {
        case .full:
            videoStream.bitrate
        case .limited(let setBitrate):
            setBitrate
        }
        
        guard let playerItem = networkAPI.getStreamingContent(
                accessToken: accessToken,
                contentID: mediaSource.id,
                bitrate: bitrateBits,
                subtitleID: subtitleID,
                audioID: audioID,
                videoID: videoID,
                sessionID: sessionID,
                title: title,
                subtitle: subtitle
              )
        else { return nil }
        let player = AVPlayer(playerItem: playerItem)
        
        self.playerProgress = JellyfinPlayerProgress(
            player: player,
            network: networkAPI,
            mediaID: mediaSource.id,
            mediaSource: mediaSource,
            videoID: videoID,
            audioID: audioID,
            subtitleID: subtitleID,
            bitrate: bitrate,
            playbackSessionID: sessionID,
            userSessionID: self.sessionID,
            accessToken: self.accessToken
        )
        self.playerProgress?.start()
        
        return player
    }
    
    func playbackEnd() {
        self.playerProgress?.stop()
        self.playerProgress = nil
    }
    
    static func getProfileImageURL(userID: String, serviceURL: URL) -> URL? {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        let url = networkAPI.getUserImageURL(userID: userID)
        print("Profile URL: \(url?.absoluteString ?? "No URL")")
        return url
    }
}

/// Describes a data structure for storing player data. Note that you must call `start()` and `stop()` manually.
protocol PlayerProtocol {
    /// Player object
    var player: AVPlayer { get }
    /// ID for the subtitles based on the server
    var subtitleID: String? { get }
    /// ID for the audio stream based on the server
    var audioID: String { get }
    /// ID for the video stream based on the server
    var videoID: String { get }
    /// Video bitrate
    var bitrate: Bitrate { get }
    /// Encompasing media source that contains the actual data
    var mediaSource: any MediaSourceProtocol { get }
    
    /// Streaming is beginning
    func start()
    /// Streaming has permanently ended for this session
    func stop()
}

final class JellyfinPlayerProgress: PlayerProtocol {
    let player: AVPlayer
    private let network: any AdvancedNetworkProtocol
    private var timer: Timer?
    private let mediaID: String
    var mediaSource: any MediaSourceProtocol
    let videoID: String
    let bitrate: Bitrate
    let audioID: String
    let subtitleID: String?
    private let playbackSessionID: String
    private let userSessionID: String
    private let accessToken: String
    
    init(
        player: AVPlayer,
        network: any AdvancedNetworkProtocol,
        mediaID: String,
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Bitrate,
        playbackSessionID: String,
        userSessionID: String,
        accessToken: String
    ) {
        self.player = player
        self.network = network
        self.mediaID = mediaID
        self.mediaSource = mediaSource
        self.videoID = videoID
        self.bitrate = bitrate
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
                    mediaSourceID: self.mediaSource.id,
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
                        mediaSourceID: self.mediaSource.id,
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
        let playbackTicks = Int(self.player.currentTime().seconds * 10_000_000)
        self.timer?.invalidate()
        self.mediaSource.startTicks = playbackTicks
        Task {
            do {
                try await self.network.updatePlaybackStatus(
                    itemID: self.mediaID,
                    mediaSourceID: self.mediaSource.id,
                    audioStreamIndex: self.audioID,
                    subtitleStreamIndex: self.subtitleID,
                    playbackPosition: playbackTicks,
                    playSessionID: self.playbackSessionID,
                    userSessionID: self.userSessionID,
                    playbackStatus: .stop,
                    accessToken: self.accessToken
                )
            } catch { }
        }
    }
}
