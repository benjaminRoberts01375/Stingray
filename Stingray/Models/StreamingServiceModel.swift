//
//  JellyfinModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit

protocol StreamingServiceProtocol: StreamingServiceBasicProtocol {
    /// Denote the current fetching status of this library. If (partially) complete this holds library data, otherwise may hold an error.
    var libraryStatus: LibraryStatus { get }
    /// The name of the user.
    var usersName: String { get }
    /// The server ID of the user.
    var userID: String { get }
    /// The name of the server.
    var serverName: String? { get }
    /// The server's version. Ex. 10.2.1
    var serverVersion: String? { get }
    /// Base path of the service.
    var serviceURL: URL { get }
    /// Track the current playback progress.
    var playerProgress: PlayerProtocol? { get }
    
    /// Download library data.
    func retrieveLibraries() async
    
    /// Inform the server that playback has begun.
    /// - Parameters:
    ///   - mediaSource: Media source being watched.
    ///   - videoID: Video stream ID.
    ///   - audioID: Audio stream ID.
    ///   - subtitleID: Subtitle stream ID. Nil = no subtitles.
    ///   - bitrate: Video bitrate of the stream.
    ///   - title: Title of the media to put on the player.
    ///   - subtitle: Subtitle, if available, to put on the player.
    /// - Returns: Playback device.
    func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Bitrate,
        title: String,
        subtitle: String?
    ) -> AVPlayer?
    
    /// Inform the server that playback has ended
    func playbackEnd()
    
    /// Link a media ID to a `MediaModel`.
    /// - Parameters:
    ///   - mediaID: Media ID to search for.
    ///   - parentID: Parent the Media ID is a part of (if available).
    /// - Returns: The found media, noting if the library is not yet finished fetching.
    func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus
    
    /// Fetch the special features for media.
    /// - Parameter media: Media to fetch for.
    func getSpecialFeatures(for media: any MediaProtocol) async throws(LibraryErrors)
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
    case error(RError)
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

/// A harness for connecting to Jellyfin.
@Observable
public final class JellyfinModel: StreamingServiceProtocol {
    /// Network used to connect to Jellyfin
    var networkAPI: AdvancedNetworkProtocol
    /// Status for downloading the library.
    var libraryStatus: LibraryStatus
    
    var usersName: String
    var userID: String
    var sessionID: String
    var accessToken: String
    var serverName: String?
    var serverID: String
    var serverVersion: String?
    var serviceURL: URL
    var playerProgress: PlayerProtocol?
    
    /// Create a `JellyfinModel` based on known data.
    /// - Parameters:
    ///   - userDisplayName: Name of the user.
    ///   - userID: Server ID of the user.
    ///   - serviceID: ID of the server.
    ///   - accessToken: Access token.
    ///   - sessionID: Validated session identifier.
    ///   - serviceURL: Base URL to the Jellyfin service.
    public init(
        userDisplayName: String,
        userID: String,
        serviceID: String,
        accessToken: String,
        sessionID: String,
        serviceURL: URL
    ) {
        // APIs
        let network = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        self.networkAPI = network
        
        // Misc properties
        self.libraryStatus = .waiting
        self.usersName = userDisplayName
        self.userID = userID
        self.serverID = serviceID
        self.accessToken = accessToken
        self.sessionID = sessionID
        self.serviceURL = serviceURL
        Task {
            do {
                let (serverVersion, serverName) = try await network.getServerVersion(accessToken: self.accessToken)
                self.serverVersion = serverVersion
                self.serverName = serverName
            }
            catch {
                self.serverVersion = nil
                self.serverName = nil
            }
        }
    }
    
    /// Create a `JellyfinModel` based on fetched data.
    /// - Parameters:
    ///   - response: Fetched data.
    ///   - serviceURL: Base URL.
    private init(response: APILoginResponse, serviceURL: URL) {
        // APIs
        let network = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        self.networkAPI = network
        
        // Properties
        self.usersName = response.userName
        self.userID = response.userId
        self.sessionID = response.sessionId
        self.accessToken = response.accessToken
        self.serverID = response.serverId
        self.libraryStatus = .waiting
        self.serviceURL = serviceURL
        self.serverVersion = response.serverVersion
    }
    
    /// Log into a Jellyfin server.
    /// - Parameters:
    ///   - url: Base URL.
    ///   - username: Signin username.
    ///   - password: Signin password.
    /// - Returns: The configured Jellyfin model.
    static func login(url: URL, username: String, password: String) async throws(AccountErrors) -> JellyfinModel {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: url))
        do {
            let response = try await networkAPI.login(username: username, password: password)
            UserModel.shared.addUser(
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
            UserModel.shared.setDefaultUser(userID: response.userId)
            return JellyfinModel(response: response, serviceURL: url)
        } catch {
            throw AccountErrors.loginFailed(error)
        }
    }
    
    /// Fetch libraries and library media.
    func retrieveLibraries() async {
        let maxConcurrentLibraries = 2
        
        self.libraryStatus = .retrieving
        let libraries: [LibraryModel]
        do {
            libraries =
            try await networkAPI.getLibraries(accessToken: self.accessToken, userID: self.userID)
                .filter { $0.libraryType != "boxsets" } // Temp fix until we support collections
        } catch {
            self.libraryStatus = .error(StreamingServiceErrors.LibrarySetupFailed(error))
            return
        }
        
        if libraries.isEmpty { return }
        
        self.libraryStatus = .available(libraries)
        await withTaskGroup(of: Void.self) { group in
            var libraryIterator = libraries.makeIterator()
            var runningTasks = 0
            
            // Fill up to maxConcurrentLibraries initially
            while runningTasks < maxConcurrentLibraries {
                if let library = libraryIterator.next() {
                    group.addTask {
                        await Task(priority: .utility) {
                            await self.retrieveLibraryContent(library: library)
                        }.value
                    }
                    runningTasks += 1
                }
                else { break }
            }
            
            // As tasks complete, start new ones
            for await _ in group {
                runningTasks -= 1
                
                if let library = libraryIterator.next() {
                    group.addTask {
                        await Task(priority: .utility) {
                            await self.retrieveLibraryContent(library: library)
                        }.value
                    }
                    runningTasks += 1
                }
            }
            
            self.libraryStatus = .complete(libraries)
        }
    }
    
    /// Fetch a single library's media.
    /// - Parameter library: Library to fetch media for.
    public func retrieveLibraryContent(library: LibraryModel) async {
        let batchSize = 100
        var currentIndex = 0
        var allMedia: [MediaModel] = []
        if case .available(let existingMedia) = library.media {
            allMedia = existingMedia
        }
        
        while true {
            let incomingMedia: [MediaModel]
            do {
                incomingMedia = try await self.networkAPI.getLibraryMedia(
                    accessToken: self.accessToken,
                    libraryId: library.id,
                    index: currentIndex,
                    count: batchSize,
                    sortOrder: .ascending,
                    sortBy: .SortName,
                    mediaTypes: [.movies([]), .tv(nil)]
                )
            } catch {
                library.media = .error(error)
                return
            }
            
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
    
    public func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [SlimMedia] {
        do {
            return try await networkAPI.getRecentlyAdded(contentType: contentType, accessToken: accessToken)
        } catch { return [] }
    }
    
    public func retrieveUpNext() async -> [SlimMedia] {
        do {
            return try await networkAPI.getUpNext(accessToken: accessToken)
        } catch {
            print("Up next failed: \(error.rDescription())")
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
    
    public func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, mediaID: mediaID, width: width)
    }

    public func getSpecialFeatures(for media: any MediaProtocol) async throws(LibraryErrors) {
        do {
            media.loadSpecialFeatures(
                specialFeatures: try await self.networkAPI.loadSpecialFeatures(mediaID: media.id, accessToken: self.accessToken)
            )
            print("Loaded special features")
        }
        catch {
            print("Failed to load special features")
            throw LibraryErrors.specialFeaturesFailed(error, media.title)
        }
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
    /// Player actively being used to watch content.
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

/// Tracks the playback status of Jellyfin content.
final class JellyfinPlayerProgress: PlayerProtocol {
    let player: AVPlayer
    /// Network to use for communicating to Jellyfin.
    private let network: any AdvancedNetworkProtocol
    /// Track how often to page Jellyfin.
    private var timer: Timer?
    var mediaSource: any MediaSourceProtocol
    let videoID: String
    let bitrate: Bitrate
    let audioID: String
    let subtitleID: String?
    /// Unique ID for playback. If settings are changed, a new ID is needed.
    private let playbackSessionID: String
    /// Server provided identifier for the session.
    private let userSessionID: String
    /// API access token.
    private let accessToken: String
    
    init(
        player: AVPlayer,
        network: any AdvancedNetworkProtocol,
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
                    mediaSourceID: self.mediaSource.id,
                    audioStreamIndex: self.audioID,
                    subtitleStreamIndex: self.subtitleID,
                    playbackPosition: TimeInterval(self.player.currentTime().seconds).ticks,
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
                        mediaSourceID: self.mediaSource.id,
                        audioStreamIndex: self.audioID,
                        subtitleStreamIndex: self.subtitleID,
                        playbackPosition: TimeInterval(self.player.currentTime().seconds).ticks,
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
        let playbackTicks = TimeInterval(self.player.currentTime().seconds).ticks
        self.timer?.invalidate()
        self.mediaSource.startPoint = TimeInterval(ticks: playbackTicks)
        Task {
            do {
                try await self.network.updatePlaybackStatus(
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
