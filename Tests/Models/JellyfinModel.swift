//
//  JellyfinModel.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/16/26.
//

import AVKit
import Foundation
import Testing
@testable import Stingray

// MARK: Mocks

/// An in-memory stand-in for a Jellyfin server
private final class FakeNetwork: AdvancedNetworkProtocol {
    /// Libraries on the server. `nil` makes the request fail
    var libraries: [LibraryModel]? = []
    /// Media held by each library or sub-folder, keyed by parent ID. Parents that aren't listed fail to load
    var media: [String: [MediaStorage]] = [:]
    /// Media returned for both recently added and up next. `nil` makes the request fail
    var shelfMedia: [MediaStorage]? = []
    /// Seasons returned for every show. `nil` makes the request fail
    var seasons: [TVSeason]? = []
    /// Number of `getSeasonMedia` calls made
    var seasonRequestCount = 0
    /// Every `recursive` flag `getMedia` was called with
    var recursiveRequests: [Bool] = []
    /// Number of `getMedia` calls made for each parent ID
    var mediaRequestCounts: [String: Int] = [:]
    /// How many more times a page should fail before succeeding, keyed by `"<parent ID>@<start index>"`
    var pageFailures: [String: Int] = [:]
    /// Number of `getMedia` calls currently waiting on a response
    private var mediaRequestsInFlight = 0
    /// Most `getMedia` calls that were ever waiting on a response at once
    var maxMediaRequestsInFlight = 0
    /// Every playback status reported, along with the playback session it was for
    var playbackReports: [(sessionID: String, status: PlaybackStatus)] = []
    /// Access token most recently logged out
    var loggedOutToken: String?

    public func getLibraries(accessToken: String, userID: String) async throws(LibraryErrors) -> [LibraryModel] {
        guard let libraries else { throw .unknown("No libraries") }
        return libraries
    }

    public func getMedia(
        accessToken: String,
        parentID: String,
        index: Int,
        count: Int,
        sortOrder: LibraryMediaSortOrder,
        sortBy: LibraryMediaSortBy,
        mediaTypes: [MediaStorage.MediaType]?,
        recursive: Bool
    ) async throws(LibraryErrors) -> MediaPage {
        recursiveRequests.append(recursive)
        mediaRequestCounts[parentID, default: 0] += 1
        // Give other requests a chance to start, like a real network would
        mediaRequestsInFlight += 1
        maxMediaRequestsInFlight = max(maxMediaRequestsInFlight, mediaRequestsInFlight)
        await Task.yield()
        mediaRequestsInFlight -= 1

        if let failuresLeft = self.pageFailures["\(parentID)@\(index)"], failuresLeft > 0 {
            self.pageFailures["\(parentID)@\(index)"] = failuresLeft - 1
            throw .unknown("Page \(index) of \(parentID) dropped")
        }
        guard let items = media[parentID] else { throw .unknown("No media for \(parentID)") }
        return MediaPage(items: Array(items.dropFirst(index).prefix(count)), totalCount: items.count)
    }

    public func getRecentlyAdded(
        contentType: RecentlyAddedMediaType,
        accessToken: String
    ) async throws(AdvancedNetworkErrors) -> [MediaStorage] {
        guard let shelfMedia else { throw .failedRecentlyAdded(LibraryErrors.unknown("Offline")) }
        return shelfMedia
    }

    public func getUpNext(accessToken: String) async throws(AdvancedNetworkErrors) -> [MediaStorage] {
        guard let shelfMedia else { throw .failedUpNext(LibraryErrors.unknown("Offline")) }
        return shelfMedia
    }

    public func getMediaImageURL(accessToken: String, imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        URL(string: "https://jellyfin.test/\(mediaID)/\(imageType.rawValue)/\(width)")
    }

    public func logoutUser(accessToken: String) async {
        loggedOutToken = accessToken
    }

    public func getStreamingContent(
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
        URL(string: "https://jellyfin.test/\(contentID)/stream").map { AVPlayerItem(url: $0) }
    }

    public func updatePlaybackStatus(
        mediaSourceID: String,
        audioStreamIndex: String,
        subtitleStreamIndex: String?,
        playbackPosition: Int,
        playSessionID: String,
        userSessionID: String,
        playbackStatus: PlaybackStatus,
        accessToken: String
    ) async throws {
        playbackReports.append((playSessionID, playbackStatus))
    }

    // Not used by these tests
    public func login(username: String, password: String) async throws(AccountErrors) -> APILoginResponse {
        throw .loginFailed(LibraryErrors.unknown("Unused"))
    }
    public func getUserImageURL(userID: String) -> URL? { nil }
    public func loadSpecialFeatures(
        mediaID: String,
        accessToken: String,
        priority: RequestPriority
    ) async throws(AdvancedNetworkErrors) -> [SpecialFeature] { [] }
    public func getSeasonMedia(accessToken: String, showID: String, priority: RequestPriority) async throws -> [TVSeason] {
        seasonRequestCount += 1
        guard let seasons else { throw LibraryErrors.unknown("No seasons for \(showID)") }
        return seasons
    }
}

// MARK: Helpers

/// Build a library with the given ID
@MainActor // For decoding
private func library(_ id: String) throws -> LibraryModel {
    try decode(LibraryModel.self, from: #"{"Id": "\#(id)", "ParentId": "root", "Name": "\#(id)", "SortName": "\#(id)"}"#)
}

/// Build a movie with the given ID, and optionally genres and a rating
@MainActor // For decoding
private func movie(_ id: String, genres: [String] = [], rating: String? = nil) throws -> MediaStorage {
    let ratingJSON = rating.map { #", "OfficialRating": "\#($0)""# } ?? ""
    let genresJSON = genres.map { "\"\($0)\"" }.joined(separator: ", ")
    return .movie(try decode(MovieModel.self, from: #"{"Id": "\#(id)", "Genres": [\#(genresJSON)]\#(ratingJSON)}"#))
}

/// Build a sub-folder with the given ID
@MainActor // For decoding
private func subFolder(_ id: String) throws -> MediaStorage {
    .subFolder(try decode(SubFolderModel.self, from: #"{"Id": "\#(id)"}"#))
}

/// Build a collection with the given ID
@MainActor // For decoding
private func collection(_ id: String) throws -> MediaStorage {
    .collection(try decode(CollectionModel.self, from: #"{"Id": "\#(id)"}"#))
}

/// IDs of the media in a group, or `nil` if its media isn't available
private func mediaIDs(_ status: MediaStatus) -> [String?]? {
    guard case .available(let media) = status else { return nil }
    return media.map(\.id)
}

/// Tests for `JellyfinModel`
@Suite("Jellyfin Model", .timeLimit(.minutes(1)))
@MainActor
public struct JellyfinModelTests {
    /// Fake network that serves the test's libraries and media
    private let network = FakeNetwork()
    /// Login response used to create the model
    public let login = APILoginResponse(
        userName: "user",
        sessionId: "session1",
        userId: "user1",
        accessToken: "token1",
        serverId: "server1",
        serverVersion: "10.11.0"
    )

    /// Create a model and wait for its libraries to finish loading
    /// - Parameter flatten: Should media in sub-folders be pulled up into their library
    /// - Returns: A model whose library status is either `.complete` or `.error`
    public func makeModel(flatten: Bool = false) async throws -> JellyfinModel {
        let url = try #require(URL(string: "https://jellyfin.test"))
        let model = JellyfinModel(response: self.login, serviceURL: url, flattenFolders: flatten, hiddenLibraryIDs: [], network: network)
        while true {
            switch model.libraryStatus {
            case .retrieving, .available: await Task.yield()
            case .complete, .error: return model
            }
        }
    }

    // MARK: Init

    /// Test that the login response lands on the right properties
    @Test
    public func copiesLoginResponse() async throws {
        let model = try await self.makeModel()

        #expect(model.usersName == "user")
        #expect(model.userID == "user1")
        #expect(model.sessionID == "session1")
        #expect(model.accessToken == "token1")
        #expect(model.serverID == "server1")
        #expect(model.serverVersion == "10.11.0")
        #expect(model.serviceURL.absoluteString == "https://jellyfin.test")
    }

    // MARK: Libraries

    /// Test that a server without libraries finishes with none
    @Test
    public func noLibrariesCompletesEmpty() async throws {
        let model = try await self.makeModel()

        guard case .complete(let libraries) = model.libraryStatus
        else {
            Issue.record("Expected .complete, got \(model.libraryStatus)")
            return
        }
        #expect(libraries.isEmpty)
    }

    /// Test that failing to get libraries puts the model in an error state
    @Test
    public func libraryFailureErrors() async throws {
        self.network.libraries = nil
        let model = try await self.makeModel()

        guard case .error = model.libraryStatus
        else {
            Issue.record("Expected .error, got \(model.libraryStatus)")
            return
        }
    }

    /// Test that each library is filled with its own media
    @Test
    public func loadsMediaIntoEachLibrary() async throws {
        let movies = try library("movies")
        let shows = try library("shows")
        self.network.libraries = [movies, shows]
        self.network.media = ["movies": [try movie("m1"), try movie("m2")], "shows": [try movie("s1")]]
        _ = try await self.makeModel()

        #expect(mediaIDs(movies.media) == ["m1", "m2"])
        #expect(mediaIDs(shows.media) == ["s1"])
    }

    /// Test that a library with nothing in it ends up empty, rather than waiting forever
    @Test
    public func emptyLibraryBecomesAvailable() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": []]
        _ = try await self.makeModel()

        #expect(mediaIDs(movies.media) == [])
    }

    /// Test that one library failing doesn't stop the others from loading
    @Test
    public func failedLibraryDoesNotAffectOthers() async throws {
        let movies = try library("movies")
        let broken = try library("broken")
        self.network.libraries = [broken, movies]
        self.network.media = ["movies": [try movie("m1")]]
        let model = try await self.makeModel()

        guard case .error = broken.media
        else {
            Issue.record("Expected the broken library to error, got \(broken.media)")
            return
        }
        #expect(mediaIDs(movies.media) == ["m1"])
        guard case .complete = model.libraryStatus
        else {
            Issue.record("Expected .complete, got \(model.libraryStatus)")
            return
        }
    }

    /// Test that libraries larger than a single page are fully loaded
    @Test
    public func pagesThroughLargeLibraries() async throws {
        let movies = try library("movies")
        let allMovies = try (1...250).map { try movie("m\($0)") }
        self.network.libraries = [movies]
        self.network.media = ["movies": allMovies]
        _ = try await self.makeModel()

        let loaded = try #require(mediaIDs(movies.media))
        #expect(Set(loaded) == Set(allMovies.map(\.id)))
        #expect(loaded.count == 250)
    }

    /// Test that each group is asked for exactly as many pages as it needs, including groups found along the way
    @Test
    public func requestsOnlyNeededPages() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = [
            "movies": try (1...250).map { try movie("m\($0)") } + [try subFolder("empty"), try subFolder("small"), try subFolder("large")],
            "empty": [],
            "small": [try movie("s1")],
            "large": try (1...150).map { try movie("l\($0)") }
        ]
        _ = try await self.makeModel()

        // 253 items in the library is 3 pages, while 150 items in the large sub-folder is 2
        #expect(self.network.mediaRequestCounts == ["movies": 3, "empty": 1, "small": 1, "large": 2])
    }

    /// Test that no more than 8 requests are waiting on the server at once, while still making use of all 8
    @Test
    public func keepsEightRequestsInFlight() async throws {
        let movies = try library("movies")
        let folderIDs = (1...20).map { "folder\($0)" }
        self.network.libraries = [movies]
        self.network.media = ["movies": try folderIDs.map { try subFolder($0) }]
        for folderID in folderIDs { self.network.media[folderID] = [try movie("\(folderID)-movie")] }
        _ = try await self.makeModel()

        #expect(self.network.maxMediaRequestsInFlight == 8)
    }

    // MARK: Failed pages

    /// Test that a failing page is retried up to 3 times, and the library loads fully without any error if one of them works
    @Test(arguments: [1, 3])
    public func droppedPageIsRetried(failures: Int) async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": try (1...250).map { try movie("m\($0)") }]
        self.network.pageFailures = ["movies@100": failures]
        _ = try await self.makeModel()

        #expect(try #require(mediaIDs(movies.media)).count == 250)
        #expect(self.network.mediaRequestCounts["movies"] == 3 + failures) // 3 pages, plus a retry for each failure
    }

    /// Test that pages failing every retry leave the library partly loaded, keeping the media that did arrive and every error
    @Test
    public func failedPagesKeepLoadedMedia() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": try (1...350).map { try movie("m\($0)") }]
        self.network.pageFailures = ["movies@100": 4, "movies@200": 4] // The first attempt plus all 3 retries
        _ = try await self.makeModel()

        guard case .partial(let items, let errors) = movies.media
        else {
            Issue.record("Expected .partial, got \(movies.media)")
            return
        }
        #expect(items.count == 150) // Pages 0 and 3
        #expect(errors.count == 2)
    }

    /// Test that the first page failing every retry errors the group, since there's nothing to show
    @Test
    public func failedFirstPageErrors() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try movie("m1")]]
        self.network.pageFailures = ["movies@0": 4]
        _ = try await self.makeModel()

        guard case .error = movies.media
        else {
            Issue.record("Expected .error, got \(movies.media)")
            return
        }
        #expect(self.network.mediaRequestCounts["movies"] == 4) // The first attempt plus 3 retries, and no more
    }

    /// Test that media in a partly loaded library can still be looked up
    @Test
    public func lookupSearchesPartialLibraries() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": try (1...150).map { try movie("m\($0)") }]
        self.network.pageFailures = ["movies@100": 4]
        let model = try await self.makeModel()

        guard case .found = model.lookup(mediaID: "m1", parentID: "movies")
        else {
            Issue.record("Expected to find m1 in the partly loaded library")
            return
        }
    }

    /// Test that genres and ratings are gathered from a library's media, with missing ratings shown as "Not Rated"
    @Test
    public func gathersGenresAndMaturity() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = [
            "movies": [
                try movie("m1", genres: ["Comedy"], rating: "PG"),
                try movie("m2", genres: ["Drama", "Comedy"], rating: "NR"),
                try movie("m3")
            ]
        ]
        _ = try await self.makeModel()

        #expect(movies.genres == ["Comedy", "Drama"])
        #expect(movies.maturity == ["PG", "Not Rated"])
    }

    // MARK: Sub-folders

    /// Test that sub-folders are kept and filled with their own media when not flattening
    @Test
    public func loadsSubFolders() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try subFolder("folder1")], "folder1": [try movie("m1")]]
        _ = try await self.makeModel(flatten: false)

        guard case .available(let media) = movies.media, case .subFolder(let folder)? = media.first
        else {
            Issue.record("Expected the library to hold a sub-folder, got \(movies.media)")
            return
        }
        #expect(mediaIDs(folder.media) == ["m1"])
        #expect(!self.network.recursiveRequests.contains(true))
    }

    /// Test that groups found while loading a library end up empty when they have nothing in them, rather than waiting forever
    @Test(arguments: [false, true])
    public func emptyNestedGroupsBecomeAvailable(flatten: Bool) async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try subFolder("folder1"), try collection("collection1")], "folder1": [], "collection1": []]
        _ = try await self.makeModel(flatten: flatten)

        guard case .available(let media) = movies.media
        else {
            Issue.record("Expected the library to be available, got \(movies.media)")
            return
        }
        for group in media {
            switch group {
            case .subFolder(let folder): #expect(mediaIDs(folder.media) == [], "\(folder.id) is \(folder.media)")
            case .collection(let collection): #expect(mediaIDs(collection.media) == [], "\(collection.id) is \(collection.media)")
            default: Issue.record("Unexpected media \(group.id)")
            }
        }
    }

    /// Test that a collection appearing in more than one library is fully loaded in each, including when it spans several pages
    @Test(arguments: [1, 250])
    public func sharedCollectionLoadsInEveryLibrary(count: Int) async throws {
        let movies = try library("movies")
        let shows = try library("shows")
        let boxSetMedia = try (1...count).map { try movie("m\($0)") }
        self.network.libraries = [movies, shows]
        self.network.media = ["movies": [try collection("boxSet")], "shows": [try collection("boxSet")], "boxSet": boxSetMedia]
        _ = try await self.makeModel()

        for library in [movies, shows] {
            guard case .available(let media) = library.media, case .collection(let boxSet)? = media.first
            else {
                Issue.record("Expected \(library.id) to hold the collection, got \(library.media)")
                continue
            }
            let loaded = try #require(mediaIDs(boxSet.media), "\(library.id)'s collection is \(boxSet.media)")
            #expect(loaded.count == count, "\(library.id)'s collection has \(loaded.count) items")
            #expect(Set(loaded) == Set(boxSetMedia.map(\.id)))
        }
    }

    /// Test that empty groups found while resyncing a library end up empty, rather than waiting forever
    @Test
    public func resyncEmptyNestedGroupsBecomeAvailable() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        let model = try await self.makeModel()

        self.network.media = ["movies": [try subFolder("folder1")], "folder1": []]
        await model.resync(library: movies, flatten: false)

        guard case .available(let media) = movies.media, case .subFolder(let folder)? = media.first
        else {
            Issue.record("Expected the library to hold a sub-folder, got \(movies.media)")
            return
        }
        #expect(mediaIDs(folder.media) == [])
    }

    /// Test that flattening asks the server for media recursively
    @Test
    public func flattenRequestsRecursively() async throws {
        self.network.libraries = [try library("movies")]
        self.network.media = ["movies": []]
        _ = try await self.makeModel(flatten: true)

        #expect(!self.network.recursiveRequests.isEmpty)
        #expect(!self.network.recursiveRequests.contains(false))
    }

    // MARK: Resync

    /// Test that resyncing marks libraries as still syncing until it finishes
    @Test
    public func resyncReportsProgress() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try movie("m1")]]
        let model = try await self.makeModel()

        let resync = Task { await model.resync(library: movies, flatten: false) }
        while self.network.mediaRequestCounts["movies"] != 2 { await Task.yield() } // Wait for the resync's request to start
        guard case .available = model.libraryStatus
        else {
            Issue.record("Expected .available while resyncing, got \(model.libraryStatus)")
            return
        }

        await resync.value
        guard case .complete = model.libraryStatus
        else {
            Issue.record("Expected .complete after resyncing, got \(model.libraryStatus)")
            return
        }
    }

    /// Test that a resync requested while libraries are still loading is ignored, rather than loading the library twice
    @Test
    public func resyncWhileSyncingIsIgnored() async throws {
        let url = try #require(URL(string: "https://jellyfin.test"))
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try movie("m1")]]
        let model = JellyfinModel(response: self.login, serviceURL: url, flattenFolders: false, hiddenLibraryIDs: [], network: network)

        await model.resync(library: movies, flatten: false)
        while case .retrieving = model.libraryStatus { await Task.yield() }
        while case .available = model.libraryStatus { await Task.yield() }

        #expect(self.network.mediaRequestCounts["movies"] == 1)
        #expect(mediaIDs(movies.media) == ["m1"])
    }

    /// Test that resyncing replaces a library's media, genres, and ratings with the server's latest
    @Test
    public func resyncReplacesMedia() async throws {
        let movies = try library("movies")
        self.network.libraries = [movies]
        self.network.media = ["movies": [try movie("old", genres: ["Horror"], rating: "R")]]
        let model = try await self.makeModel()

        self.network.media = ["movies": [try movie("new", genres: ["Comedy"], rating: "PG")]]
        await model.resync(library: movies, flatten: false)

        #expect(mediaIDs(movies.media) == ["new"])
        #expect(movies.genres == ["Comedy"])
        #expect(movies.maturity == ["PG"])
    }

    // MARK: Lookup

    /// Test that media can be found in any library, regardless of the parent ID given
    @Test(arguments: ["movies", "shows", nil])
    public func lookupFindsMedia(parentID: String?) async throws {
        self.network.libraries = [try library("movies"), try library("shows")]
        self.network.media = ["movies": [try movie("m1")], "shows": [try movie("s1")]]
        let model = try await self.makeModel()

        guard case .found(let media) = model.lookup(mediaID: "s1", parentID: parentID)
        else {
            Issue.record("Expected to find s1")
            return
        }
        #expect(media.id == "s1")
    }

    /// Test that media inside a sub-folder can be found
    @Test
    public func lookupSearchesSubFolders() async throws {
        self.network.libraries = [try library("movies")]
        self.network.media = ["movies": [try subFolder("folder1")], "folder1": [try movie("m1")]]
        let model = try await self.makeModel()

        guard case .found(let media) = model.lookup(mediaID: "m1", parentID: "movies")
        else {
            Issue.record("Expected to find m1 inside the sub-folder")
            return
        }
        #expect(media.id == "m1")
    }

    /// Test that media only reachable through a collection can be found, including a collection nested in a sub-folder
    @Test
    public func lookupSearchesCollections() async throws {
        self.network.libraries = [try library("movies")]
        self.network.media = [
            "movies": [try collection("boxSet"), try subFolder("folder1")],
            "boxSet": [try movie("m1")],
            "folder1": [try collection("nestedBoxSet")],
            "nestedBoxSet": [try movie("m2")]
        ]
        let model = try await self.makeModel()

        for mediaID in ["m1", "m2"] {
            guard case .found(let media) = model.lookup(mediaID: mediaID, parentID: "movies")
            else {
                Issue.record("Expected to find \(mediaID) inside its collection")
                continue
            }
            #expect(media.id == mediaID)
        }
    }

    /// Test that missing media is reported as not found once every library has loaded
    @Test
    public func lookupMissingMediaIsNotFound() async throws {
        self.network.libraries = [try library("movies")]
        self.network.media = ["movies": [try movie("m1")]]
        let model = try await self.makeModel()

        guard case .notFound = model.lookup(mediaID: "missing", parentID: nil)
        else {
            Issue.record("Expected .notFound")
            return
        }
    }

    /// Test that lookups made before libraries finish loading may succeed later
    @Test
    public func lookupWhileLoadingIsTemporarilyNotFound() throws {
        let url = try #require(URL(string: "https://jellyfin.test"))
        let model = JellyfinModel(response: self.login, serviceURL: url, flattenFolders: false, hiddenLibraryIDs: [], network: network)

        guard case .temporarilyNotFound = model.lookup(mediaID: "m1", parentID: nil)
        else {
            Issue.record("Expected .temporarilyNotFound")
            return
        }
    }

    // MARK: Shelves

    /// Test that recently added and up next pass along the server's media
    @Test
    public func shelvesReturnServerMedia() async throws {
        self.network.shelfMedia = [try movie("m1"), try movie("m2")]
        let model = try await self.makeModel()

        #expect(await model.retrieveRecentlyAdded(.all).map(\.id) == ["m1", "m2"])
        #expect(await model.retrieveUpNext().map(\.id) == ["m1", "m2"])
    }

    /// Test that recently added and up next fall back to empty when the server fails
    @Test
    public func shelvesAreEmptyOnFailure() async throws {
        self.network.shelfMedia = nil
        let model = try await self.makeModel()

        #expect(await model.retrieveRecentlyAdded(.movie).isEmpty)
        #expect(await model.retrieveUpNext().isEmpty)
    }

    // MARK: Extra data

    /// Test that a failed seasons load is marked as failed, rather than staying stuck loading, and can then be retried
    @Test
    public func failedSeasonsLoadCanBeRetried() async throws {
        let show = try decode(TVShowModel.self, from: #"{"Id": "show1"}"#)
        let model = try await self.makeModel()

        // Wait for the request to come back, however it ends
        func waitForSeasons() async {
            for _ in 0..<100 {
                guard case .loading = show.seasons else { return }
                await Task.yield()
            }
        }

        self.network.seasons = nil
        model.getExtraMediaData(for: show, priority: .high)
        await waitForSeasons()
        guard case .failed = show.seasons
        else {
            Issue.record("Expected .failed after a failed load, got \(show.seasons)")
            return
        }

        self.network.seasons = []
        model.getExtraMediaData(for: show, priority: .high)
        await waitForSeasons()
        guard case .loaded = show.seasons
        else {
            Issue.record("Expected .loaded after retrying, got \(show.seasons)")
            return
        }
        #expect(self.network.seasonRequestCount == 2)
    }

    // MARK: Playback

    /// Test that starting playback while a session is still running ends that session, rather than leaving it reporting to the server
    @Test
    public func playbackStartEndsPreviousSession() async throws {
        let source = try decode(MediaSource.self, from: """
        {"Id": "source1", "Name": "1080p", "MediaStreams": [{"Index": 0, "Type": "Video"}, {"Index": 1, "Type": "Audio"}]}
        """)
        let model = try await self.makeModel()
        let player = AVPlayer()

        // Start playback on the shared player
        func start() {
            model.playbackStart(
                mediaSource: source,
                videoID: "0",
                audioID: "1",
                subtitleID: nil,
                bitrate: nil,
                title: "Movie",
                subtitle: nil,
                player: player
            )
        }
        start()
        start() // No playbackEnd in between

        // Wait for both sessions to report they've started, plus the first one's stop
        for _ in 0..<100 where self.network.playbackReports.filter({ $0.status == .play }).count < 2 ||
            !self.network.playbackReports.contains(where: { $0.status == .stop }) {
            await Task.yield()
        }
        let sessions = self.network.playbackReports.filter { $0.status == .play }.map(\.sessionID)
        try #require(sessions.count == 2 && sessions[0] != sessions[1], "Expected two separate sessions, got \(sessions)")
        let stopped = self.network.playbackReports.filter { $0.status == .stop }.map(\.sessionID)
        #expect(stopped == [sessions[0]]) // Only the replaced session is over
        #expect(model.playerProgress != nil)
    }

    // MARK: Misc

    /// Test that image URLs come from the network
    @Test
    public func imageURLComesFromNetwork() async throws {
        let model = try await self.makeModel()

        let url = model.getImageURL(imageType: .backdrop, mediaID: "m1", width: 500)
        #expect(url?.absoluteString == "https://jellyfin.test/m1/Backdrop/500")
    }

    /// Test that logging out expires the model's access token
    @Test
    public func logoutExpiresToken() async throws {
        let model = try await self.makeModel()

        await model.logout()
        #expect(self.network.loggedOutToken == "token1")
    }
}
