//
//  StreamingServiceModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit
import UIKit

/// Basic information about the connected server
public protocol SystemInfoProviding {
    /// Name of the server
    var serverName: String? { get }
    /// Version of software the server is running
    var serverVersion: String? { get }
    /// Base path of the service.
    var serviceURL: URL { get }
}

/// Holds information about the available libraries
public protocol LibraryProviding {
    /// Denote the current fetching status of this library. If (partially) complete this holds library data, otherwise may hold an error.
    var libraryStatus: LibraryStatus { get }
    /// Resync a given library with the server
    /// - Parameters:
    ///   - library: Library to resync
    ///   - flatten: Should data media within the library maintain their sub-folders, or group all media together
    func resync(library: any LibraryProtocol, flatten: Bool) async
    
    /// Fetch libraries and library media.
    /// - Parameters:
    ///   - flatten: Should media in sub-folders remain in sub-folders
    func retrieveLibraries(flatten: Bool) async
}

/// Describes the current setup status for a downloaded library
public enum LibraryStatus {
    /// The library object has been created and is fetching
    case retrieving
    /// Some of the library's content is available, but we're still fetching
    case available([LibraryModel])
    /// All of this library's content has been downloaded
    case complete([LibraryModel])
    /// The library has errored out
    case error(RError)
}

/// Holds info about media currently playing
public protocol PlayerProviding {
    /// Track the current playback progress.
    var playerProgress: PlayerProtocol? { get }

    /// Setup playback, informs the server about playback status
    /// - Parameters:
    ///   - mediaSource: Media source being watched.
    ///   - videoID: Video stream ID.
    ///   - audioID: Audio stream ID.
    ///   - subtitleID: Subtitle stream ID. Nil = no subtitles.
    ///   - bitrate: Target video bitrate of the stream. Nil = unlimited bitrate
    ///   - title: Title of the media to put on the player.
    ///   - subtitle: Subtitle, if available, to put on the player.
    ///   - player: An AVPlayer instance to update and use.
    func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Int?,
        title: String,
        subtitle: String?,
        player: AVPlayer
    )

    /// Inform the server that playback has ended
    func playbackEnd()
}

/// Provides user actions with the server
public protocol UserProviding {
    /// The name of the user.
    var usersName: String { get }
    /// The server ID of the user.
    var userID: String { get }

    /// Logout the current user
    func logout() async
}

/// Loading media functions
public protocol MediaProviding {
    /// Link a media ID to its `MediaStorage`.
    /// - Parameters:
    ///   - mediaID: Media ID to search for.
    ///   - parentID: Parent the Media ID is a part of (if available).
    /// - Returns: The found media, noting if the library is not yet finished fetching.
    func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus

    /// Fetch any additional data (ex special features) for this media.
    /// - Parameter media: Media to fetch for.
    /// - Parameter priority: How prudent the info is to get right now
    func getExtraMediaData(for media: any SpecialFeaturesProtocol & MediaMetadataProtocol, priority: RequestPriority)
}

/// Denotes the availablity of a piece of media
public enum MediaLookupStatus {
    /// The requested media was found
    case found(MediaStorage)
    /// The requested media was not found, but may be available once libraries finish downloading
    case temporarilyNotFound
    /// The requested media was not found despite all libraries being downloaded
    case notFound
}

/// A harness for authenticating with quick connect
public final class JellyfinQuickConnectModel {
    /// Network used to connect to jellyfin
    private var networkAPI: JellyfinAdvancedNetwork
    /// The URL of the jellyfin server
    public var serviceURL: URL
    /// The secret after quick connect is initialted
    private var quickConnectSecret: String?

    /// Create a `JellyfinQuickConnectModel` based on URL
    /// - Parameters:
    ///   - url: The URL of the jellyfin server
    public init(url: URL) {
        self.serviceURL = url
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: url))
    }

    /// Check if quick connect is enabled on the server
    /// - Returns: A bool if quick connect is enabled or not
    /// - Throws: Throws when unable to check if Quick Connect is enabled due to network issues
    public func getQuickConnectEnabled() async throws(QuickConnectErrors) -> Bool {
        do { return try await networkAPI.quickConnectAvailable() }
        catch { throw QuickConnectErrors.isEnabled(error) }
    }

    /// Get the quick connect code and the secret for verification
    /// - Returns: The quick connect code a user has to enter
    /// - Throws: Only throws when Stingray is unable to obtain a Quick Connect code due to network issues
    public func getQuickConnectCodes() async throws(QuickConnectErrors) -> String {
        do {
            let (code, secret) = try await networkAPI.getQuickConnectCodes()
            quickConnectSecret = secret
            return code
        }
        catch { throw QuickConnectErrors.quickConnectCodesFailed(error) }
    }

    /// Checks the quick connect authentication state, returns a secret if authenticated
    /// The secret can be used to log the user in
    /// - Returns: The secret if the session authenticated, nil if authentication is still pending
    /// - Throws: Only throws when Stingray is unable to verify the user entered the Quick Connect code due to network issues
    public func getQuickConnectSecret() async throws(QuickConnectErrors) -> String? {
        guard let quickConnectSecret else {
            Log.error("Could get load quick connect secret - make sure to call getQuickConnectCodes() first")
            return nil
        }
        do {
            let authenticated = try await self.networkAPI.quickConnectAuthenticated(secret: quickConnectSecret)
            return authenticated ? quickConnectSecret : nil
        }
        catch let err as RError { throw .statusFailedtoFetch(err) }
    }
}

/// A harness for connecting to Jellyfin.
@MainActor
@Observable
public final class JellyfinModel: SystemInfoProviding, LibraryProviding, PlayerProviding, UserProviding, MediaProviding,
                                  MediaImageProviding, RecommendationProviding {
    /// Network used to connect to Jellyfin
    public var networkAPI: AdvancedNetworkProtocol
    /// Status for downloading the library.
    public var libraryStatus: LibraryStatus

    public var usersName: String
    public var userID: String
    public var sessionID: String
    public var accessToken: String
    public var serverName: String?
    public var serverID: String
    public var serverVersion: String?
    public var serviceURL: URL
    public var playerProgress: PlayerProtocol?

    /// Create a `JellyfinModel` based on known data.
    /// - Parameters:
    ///   - userDisplayName: Name of the user.
    ///   - userID: Server ID of the user.
    ///   - serviceID: ID of the server.
    ///   - accessToken: Access token.
    ///   - sessionID: Validated session identifier.
    ///   - serviceURL: Base URL to the Jellyfin service.
    ///   - flattenFolders: Should media in sub-folders be pulled up into their library
    public init(
        userDisplayName: String,
        userID: String,
        serviceID: String,
        accessToken: String,
        sessionID: String,
        serviceURL: URL,
        flattenFolders: Bool
    ) {
        // APIs
        let network = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        self.networkAPI = network

        // Misc properties
        self.libraryStatus = .retrieving
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
            catch let error as RError {
                self.serverVersion = nil
                self.serverName = nil
                Log.error("Failed to get server version: \(error.localizedDescription)")
                self.libraryStatus = .error(StreamingServiceErrors.serverVersionFailed(error))
                return
            }
            catch let error {
                Log.error("Failed to get server version: \(error.localizedDescription)")
                self.libraryStatus = .error(StreamingServiceErrors.serverVersionFailed(nil))
                return
            }
            await self.retrieveLibraries(flatten: flattenFolders)
        }
    }

    /// Create a `JellyfinModel` based on fetched data.
    /// - Parameters:
    ///   - response: Fetched data.
    ///   - serviceURL: Base URL.
    ///   - flattenFolders: Should media in sub-folders be pulled up into their library
    private init(response: APILoginResponse, serviceURL: URL, flattenFolders: Bool) {
        // APIs
        let network = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        self.networkAPI = network

        // Properties
        self.usersName = response.userName
        self.userID = response.userId
        self.sessionID = response.sessionId
        self.accessToken = response.accessToken
        self.serverID = response.serverId
        self.libraryStatus = .retrieving
        self.serviceURL = serviceURL
        self.serverVersion = response.serverVersion

        Task { await self.retrieveLibraries(flatten: flattenFolders) }
    }

    /// Log into a Jellyfin server.
    /// - Parameters:
    ///   - url: Base URL.
    ///   - username: Signin username.
    ///   - password: Signin password.
    ///   - userModel: User storage to load the user from
    ///   - settingsModel: Settings model to write updated settings to
    /// - Returns: The configured Jellyfin model.
    public static func login(
        url: URL,
        username: String,
        password: String,
        userModel: UserModelProtocol,
        settingsModel: SettingsModel
    ) async throws(AccountErrors) -> (JellyfinModel, User) {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: url))
        let response: APILoginResponse

        do { response = try await networkAPI.login(username: username, password: password) }
        catch { throw AccountErrors.loginFailed(error) }

        return Self.baseLogin(userModel: userModel, settingsModel: settingsModel, response: response, url: url)
    }

    /// Log into a Jellyfin server using the quick connect feature
    /// - Parameters:
    ///   - url: Base URL.
    ///   - quickConnectSecret: The quick connect secret retrieved by the server
    ///   - userModel: User storage to load the user from
    ///   - settingsModel: Settings model to write updated settings to
    /// - Returns: The configured Jellyfin model.
    public static func login(
        url: URL,
        quickConnectSecret: String,
        userModel: UserModelProtocol,
        settingsModel: SettingsModel
    ) async throws(QuickConnectErrors) -> (JellyfinModel, User) {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: url))
        let response: APILoginResponse

        do { response = try await networkAPI.login(quickConnectSecret: quickConnectSecret) }
        catch { throw QuickConnectErrors.loginFailed(error) }

        return Self.baseLogin(userModel: userModel, settingsModel: settingsModel, response: response, url: url)
    }

    /// Handles the business logic of setting up new/existing users
    /// - Parameters:
    ///   - userModel: Location to store the user
    ///   - settingsModel: Settings to sync to the newly active user
    ///   - response: Server response for this user
    ///   - url: Location of the server
    /// - Returns: Setup login instance
    private static func baseLogin(
        userModel: UserModelProtocol,
        settingsModel: SettingsModel,
        response: APILoginResponse,
        url: URL
    ) -> (JellyfinModel, User) {
        let workingUser: User
        if let existingUser = userModel.getUser(id: response.userId) { // User already exists, just update access
            existingUser.serviceType = .Jellyfin(UserJellyfin(accessToken: response.accessToken, sessionID: response.sessionId))
            existingUser.serviceURL = url
            existingUser.serviceID = response.serverId
            workingUser = existingUser
        }
        else { // User doesn't exist, setup from scratch
            let newUser = userModel.createUser(
                serviceURL: url,
                serviceType: .Jellyfin(
                    UserJellyfin(accessToken: response.accessToken, sessionID: response.sessionId)
                ),
                serviceID: response.serverId,
                id: response.userId,
                displayName: response.userName
            )

            userModel.activeUser = newUser
            workingUser = newUser
        }
        // Settings read and write through whichever user they're pointed at, so they have to follow the login
        settingsModel.switchUser(to: workingUser)
        // Sync the theme cache to the newly active user so we don't keep showing the previous user's theme
        settingsModel.themeDark = workingUser.darkTheme
        settingsModel.themeLight = workingUser.lightTheme
        return (
            JellyfinModel(response: response, serviceURL: url, flattenFolders: workingUser.flattenFolders),
            workingUser
        )
    }

    public func logout() async {
        await self.networkAPI.logoutUser(accessToken: self.accessToken)
    }

    public func retrieveLibraries(flatten: Bool) async {
        // Get all libraries. They'll be empty for now
        let libraries: [LibraryModel]
        do {
            libraries = try await networkAPI.getLibraries(
                accessToken: self.accessToken,
                userID: self.userID
            )
        }
        catch let error as RError {
            let wrappedError = StreamingServiceErrors.librarySetupFailed(error)
            self.libraryStatus = .error(wrappedError)
            Log.warning("Failed to get libraries: \(wrappedError.rDescription())")
            return
        }

        if libraries.isEmpty {
            self.libraryStatus = .complete([])
            return
        }

        self.libraryStatus = .available(libraries)
        await self.fetchMedia(for: libraries, batchSize: 100, flatten: flatten)
        self.libraryStatus = .complete(libraries)
    }

    /// Page in media for a set of groups, keeping several requests in flight at once.
    /// Groups are worked through in order, moving on once the current one returns a short page or an error.
    /// - Parameters:
    ///   - groups: Groups to fill with media. Their media should already be `.waiting`.
    ///   - batchSize: Number of items to request per page.
    ///   - flatten: Should media in sub-folders remain in sub-folders
    private func fetchMedia(for groups: [any GroupMetadataProtocol], batchSize: Int, flatten: Bool) async {
        enum GroupContent {
            case success([MediaStorage])
            case error(RError)
        }

        await withTaskGroup(of: (String, GroupContent).self) { group in
            var pageTracker: [String : Int] = [:]
            let groupsIterator = groups.makeAppendableIterator()

            func getMedia(parentID: String?) {
                guard let parentID = parentID // Every group has been fully requested
                else { return }
                let index = (pageTracker[parentID] ?? -1) + 1
                pageTracker[parentID] = index
                group.addTask {
                    do {
                        return (
                            parentID,
                            GroupContent.success(
                                try await self.networkAPI.getMedia(
                                    accessToken: self.accessToken,
                                    parentID: parentID,
                                    index: index * batchSize,
                                    count: batchSize,
                                    sortOrder: .ascending,
                                    sortBy: .sortName,
                                    mediaTypes: [.movie, .tvShow, .homeVideo] + (flatten ? [] : [.subFolder]),
                                    recursive: flatten
                                )
                            )
                        )
                    }
                    catch let error as RError { return (parentID, GroupContent.error(LibraryErrors.gettingLibraries(error))) }
                    catch { return (parentID, GroupContent.error(LibraryErrors.unknown(error.localizedDescription))) }
                }
            }

            // Spin up tasks to download content from each group.
            // We'll almost defintely have too many requests hitting a library at first, but that's fine
            // since we can't know how many items are in each library, and they'll return fast to be
            // reused in the next loop
            for _ in 0..<8 { getMedia(parentID: groupsIterator.current?.id) }

            // Read from the buffer and setup next request
            for await (groupID, content) in group {
                if let group = groupsIterator.storage.first(where: { $0.id == groupID }) {
                    let reachedEnd: Bool
                    switch content {
                    case .error(let error):
                        Log.warning("Failed to get content for group \(groupID): \(error.rDescription())")
                        group.media = .error(error)
                        reachedEnd = true
                    case .success(let newMedia):
                        self.append(newMedia, to: group)
                        // Is there a group in this array we need to get media for?
                        for media in newMedia where media.isGroup {
                            switch media {
                            case .subFolder(let subfolder): groupsIterator.append(subfolder)
                            case .error, .example, .homeVideo, .movie, .tvShow: break
                            }
                        }
                        reachedEnd = newMedia.count < batchSize // A short page means there's nothing left to request
                    }
                    // Advance to the next group. Stragglers from a group we've already moved past shouldn't skip the current one
                    if reachedEnd && groupID == groupsIterator.current?.id { _ = groupsIterator.next() }
                }
                getMedia(parentID: groupsIterator.current?.id) // Startup next task
                // When we finish with the tasks, we simply fall out of the loop
            }
        }

        // Every page came back blank, so the group really is empty. Leaving it as `.waiting` would spin forever.
        for group in groups {
            if case .waiting = group.media { group.media = .available([]) }
        }
    }

    /// Add a freshly fetched page of media to a library, keeping its filter options up to date.
    /// - Parameters:
    ///   - newMedia: Page of media from the server.
    ///   - group: Group to add media to
    private func append(_ newMedia: [MediaStorage], to group: any GroupMetadataProtocol) {
        if newMedia.isEmpty { return } // Don't update the UI with blank media
        switch group.media {
        case .error: return // We already errored this group, no need to log it again
        case .waiting: group.media = .available(newMedia)
        case .available(var existingItems):
            group.media = .waiting // Micro optimizing >:D
            existingItems.append(contentsOf: newMedia)
            group.media = .available(existingItems)
        }
        group.genres.formUnion(newMedia.flatMap { $0.genres ?? [] })
        group.maturity.formUnion(newMedia.flatMap { media -> Set<String> in
            // Individual media carry a single rating, while sub-folders have already gathered the ratings of their contents
            let ratings: Set<String?>
            switch media {
            case .movie(let movie), .example(let movie): ratings = [movie.maturity]
            case .tvShow(let tvShow): ratings = [tvShow.maturity]
            case .homeVideo(let homeVideo): ratings = [homeVideo.maturity]
            case .subFolder(let subfolder): ratings = Set(subfolder.maturity)
            case .error: ratings = [nil]
            }
            return Set(ratings.map { maturity in
                guard let maturity, maturity != "NR", maturity != "Unknown"
                else { return "Not Rated" }
                return maturity
            })
        })
    }

    /// Remove media from the top level of a library, such as once it's been moved into a sub-folder.
    /// - Parameters:
    ///   - mediaIDs: IDs of the media to remove.
    ///   - library: Library to remove the media from.
    private func remove(mediaIDs: Set<String>, from library: any LibraryProtocol) {
        guard case .available(var existingItems) = library.media
        else { return }
        library.media = .waiting // Micro optimizing >:D
        existingItems.removeAll { $0.id.map(mediaIDs.contains) ?? false }
        library.media = .available(existingItems)
    }

    public func retrieveRecentlyAdded(_ contentType: RecentlyAddedMediaType) async -> [MediaStorage] {
        do { return try await networkAPI.getRecentlyAdded(contentType: contentType, accessToken: accessToken) }
        catch { return [] }
    }

    public func retrieveUpNext() async -> [MediaStorage] {
        do { return try await networkAPI.getUpNext(accessToken: accessToken) }
        catch {
            Log.warning("Up next failed: \(error.rDescription())")
            return []
        }
    }

    public func resync(library: any LibraryProtocol, flatten: Bool) async {
        Log.info("Reloading the library \"\(library.title)\"...")
        // Dump all the existing media
        library.media = .waiting
        library.genres = Set()
        library.maturity = Set()

        // A bit more aggressive than retrieveLibraries since there'll be fewer requests
        await self.fetchMedia(for: [library], batchSize: 200, flatten: flatten)
    }

    public func lookup(mediaID: String, parentID: String?) -> MediaLookupStatus {
        let libraries: [LibraryModel]
        switch self.libraryStatus {
        case .available(let libs), .complete(let libs): libraries = libs
        default: return .temporarilyNotFound
        }

        // Check the parent library first (most likely location)
        if let parentID = parentID,
           let parentLibrary = libraries.first(where: { $0.id == parentID }) {
            let allMedia: [MediaStorage]?
            switch parentLibrary.media {
            case .available(let media): allMedia = media
            default: allMedia = nil
            }

            if let allMedia = allMedia,
               let found = Self.find(mediaID: mediaID, in: allMedia) {
                return .found(found)
            }
        }

        // Fallback: search all libraries
        for library in libraries {
            let allMedia: [MediaStorage]?
            switch library.media {
            case .available(let media): allMedia = media
            default: allMedia = nil
            }

            if let allMedia = allMedia,
               let found = Self.find(mediaID: mediaID, in: allMedia) {
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

    /// Search for media by ID, descending into sub-folders.
    /// - Parameters:
    ///   - mediaID: Media ID to search for.
    ///   - media: Media to search through.
    /// - Returns: The matching media, if found.
    private static func find(mediaID: String, in media: [MediaStorage]) -> MediaStorage? {
        for item in media {
            if item.id == mediaID { return item }
            if case .subFolder(let subFolder) = item,
               case .available(let subFolderMedia) = subFolder.media,
               let found = find(mediaID: mediaID, in: subFolderMedia) {
                return found
            }
        }
        return nil
    }

    public func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        return networkAPI.getMediaImageURL(accessToken: accessToken, imageType: imageType, mediaID: mediaID, width: width)
    }

    public func getExtraMediaData(for media: any SpecialFeaturesProtocol & MediaMetadataProtocol, priority: RequestPriority) {
        if let show = media as? any TVShowProtocol { // Episodes
            switch show.seasons {
            case .unloaded:
                show.loadSeasons(.loading)
                Task(priority: priority == .high ? .high : nil) {
                    do {
                        show.loadSeasons(
                            .loaded(try await self.networkAPI.getSeasonMedia(
                                accessToken: self.accessToken,
                                showID: media.id,
                                priority: .high
                            ))
                        )
                    }
                    catch let error as RError {
                        Log.warning("Failed to load seasons: \(LibraryErrors.gettingSeasons(error, media.id).rDescription())")
                        return
                    }
                    catch {
                        Log.warning(
                            "Failed to generate correct error for failed seasons load: " +
                            LibraryErrors.gettingSeasons(nil, media.id).rDescription()
                        )
                        return
                    }
                }
            case .loading, .loaded: break
            }
        }
        Task(priority: priority == .high ? .high : nil) { // Special features
            switch media.specialFeatures {
            case .unloaded:
                do {
                    media.loadSpecialFeatures(
                        specialFeatures: try await self.networkAPI.loadSpecialFeatures(
                            mediaID: media.id,
                            accessToken: self.accessToken,
                            priority: .high
                        )
                    )
                }
                catch let error as RError {
                    Log.warning(
                            "Failed to load special features: \(LibraryErrors.specialFeaturesFailed(error, media.title).rDescription())"
                        )
                }
                catch {
                    Log.warning(
                        "Failed to generate correct error for failed special features load: " +
                        LibraryErrors.specialFeaturesFailed(nil, media.title).rDescription()
                    )
                }
            case .loading, .loaded: break
            }
        }
    }

    public func playbackStart(
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Int?,
        title: String,
        subtitle: String?,
        player: AVPlayer
    ) {
        let sessionID = UUID().uuidString
        guard let videoStream = mediaSource.videoStreams.first(where: { $0.id == videoID })
        else {
            Log.error("No video streams available for \(mediaSource.name) - \(mediaSource.id)")
            return
        }
        let bitrateBits = bitrate ?? videoStream.bitrate

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
        else {
            Log.error("Failed to generate a player item for \(mediaSource.name) - \(mediaSource.id)")
            return
        }
        player.replaceCurrentItem(with: playerItem)

        self.playerProgress = JellyfinPlayerProgress(
            player: player,
            network: networkAPI,
            mediaSource: mediaSource,
            videoID: videoID,
            audioID: audioID,
            subtitleID: subtitleID,
            bitrate: bitrateBits,
            playbackSessionID: sessionID,
            userSessionID: self.sessionID,
            accessToken: self.accessToken
        )
        self.playerProgress?.start()
    }

    public func playbackEnd() {
        self.playerProgress?.stop()
        self.playerProgress = nil
    }

    public static func getProfileImageURL(userID: String, serviceURL: URL) -> URL? {
        let networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: serviceURL))
        let url = networkAPI.getUserImageURL(userID: userID)
        Log.debug("Profile URL: \(url?.absoluteString ?? "No URL")")
        return url
    }
}

/// Describes a data structure for storing player data. Note that you must call `start()` and `stop()` manually.
public protocol PlayerProtocol {
    /// Player actively being used to watch content.
    var player: AVPlayer { get }
    /// ID for the subtitles based on the server
    var subtitleID: String? { get }
    /// ID for the audio stream based on the server
    var audioID: String { get }
    /// ID for the video stream based on the server
    var videoID: String { get }
    /// Video bitrate
    var bitrate: Int { get }
    /// Encompasing media source that contains the actual data
    var mediaSource: any MediaSourceProtocol { get }

    /// Streaming is beginning
    func start()
    /// Streaming has permanently ended for this session
    func stop()
}

/// Tracks the playback status of Jellyfin content.
public final class JellyfinPlayerProgress: PlayerProtocol {
    public var player: AVPlayer
    /// Network to use for communicating to Jellyfin.
    private let network: any AdvancedNetworkProtocol
    /// Background loop that periodically reports playback progress to Jellyfin, off the main thread.
    private var playerProgressTask: Task<Void, Never>?
    public var mediaSource: any MediaSourceProtocol
    public let videoID: String
    public let bitrate: Int
    public let audioID: String
    public let subtitleID: String?
    /// Unique ID for playback. If settings are changed, a new ID is needed.
    private let playbackSessionID: String
    /// Server provided identifier for the session.
    private let userSessionID: String
    /// API access token.
    private let accessToken: String

    public init(
        player: AVPlayer,
        network: any AdvancedNetworkProtocol,
        mediaSource: any MediaSourceProtocol,
        videoID: String,
        audioID: String,
        subtitleID: String?,
        bitrate: Int,
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
        self.playerProgressTask = nil
        self.playbackSessionID = playbackSessionID
        self.userSessionID = userSessionID
        self.accessToken = accessToken
        let playbackPos = TimeInterval(self.player.currentTime().seconds).ticks
        Task {
            try? await self.network.updatePlaybackStatus(
                mediaSourceID: self.mediaSource.id,
                audioStreamIndex: self.audioID,
                subtitleStreamIndex: self.subtitleID,
                playbackPosition: playbackPos,
                playSessionID: self.playbackSessionID,
                userSessionID: self.userSessionID,
                playbackStatus: .play,
                accessToken: self.accessToken
            )
        }
    }

    deinit { self.playerProgressTask?.cancel() }

    public func start() {
        // Run the progress loop off the main thread so periodic reporting never hitches the UI.
        self.playerProgressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self
                else { return }

                let playbackStatus: PlaybackStatus
                switch self.player.timeControlStatus {
                case .playing: playbackStatus = .progressed
                default: playbackStatus = .paused
                }

                let playbackPos = TimeInterval(self.player.currentTime().seconds).ticks
                try? await self.network.updatePlaybackStatus(
                    mediaSourceID: self.mediaSource.id,
                    audioStreamIndex: self.audioID,
                    subtitleStreamIndex: self.subtitleID,
                    playbackPosition: playbackPos,
                    playSessionID: self.playbackSessionID,
                    userSessionID: self.userSessionID,
                    playbackStatus: playbackStatus,
                    accessToken: self.accessToken
                )
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    public func stop() {
        let playbackTicks = TimeInterval(self.player.currentTime().seconds).ticks
        self.playerProgressTask?.cancel()
        self.mediaSource.startPoint = TimeInterval(ticks: playbackTicks)
        Task {
            try? await self.network.updatePlaybackStatus(
                mediaSourceID: self.mediaSource.id,
                audioStreamIndex: self.audioID,
                subtitleStreamIndex: self.subtitleID,
                playbackPosition: playbackTicks,
                playSessionID: self.playbackSessionID,
                userSessionID: self.userSessionID,
                playbackStatus: .stop,
                accessToken: self.accessToken
            )
        }
    }
}
