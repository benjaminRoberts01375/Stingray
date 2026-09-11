//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

/// The landing tab, showing rows of recommended media followed by server and library summaries.
public struct HomeView: View {
    /// Streaming service used to source recommendations and artwork
    public let streamingService: RecommendationProviding & MediaImageProviding & SystemInfoProviding & LibraryProviding

    /// Fetched media keyed by `HomeRow.id`. Held here rather than in each row so that switching tabs doesn't refetch every row.
    @State private var dashboardCache: [String: [MediaModelRepresentable]] = [:]
    /// App navigation, forwarded to each media card
    @Binding public var navigation: NavigationPath

    public var body: some View {
        VStack(alignment: .leading) {
            DashboardRow(
                rowType: .nextUp,
                streamingService: self.streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await self.streamingService.retrieveUpNext()
            }
            .focusSection()

            DashboardRow(
                rowType: .recentlyAdded,
                streamingService: self.streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await self.streamingService.retrieveRecentlyAdded(.all)
            }
            .focusSection()

            DashboardRow(
                rowType: .latestMovies,
                streamingService: self.streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await self.streamingService.retrieveRecentlyAdded(.movie)
            }
            .focusSection()

            DashboardRow(
                rowType: .latestShows,
                streamingService: self.streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await self.streamingService.retrieveRecentlyAdded(.tv)
            }
            .focusSection()

            VStack {
                SystemInfoView(streamingService: self.streamingService)
                LibrariesInfoView(streamingService: self.streamingService)
            }
            .frame(maxWidth: .infinity)
            .padding(.top)
        }
    }
}

/// The recommendation rows shown on the home tab, in display order.
fileprivate enum HomeRow: Identifiable {
    /// Partially watched shows, and the next episode of shows the user has finished an episode of
    case nextUp
    /// Most recently added media of any type
    case recentlyAdded
    /// Most recently added movies
    case latestMovies
    /// Most recently added TV shows
    case latestShows

    /// Stable key used both for SwiftUI identity and as the `HomeView` cache key
    var id: String {
        switch self {
        case .nextUp: return "nextUp"
        case .recentlyAdded: return "recentlyAdded"
        case .latestMovies: return "latestMovies"
        case .latestShows: return "latestShows"
        }
    }

    /// User-facing row heading
    var name: LocalizedStringKey {
        switch self {
        case .nextUp: return "Next Up"
        case .recentlyAdded: return "Recently Added"
        case .latestMovies: return "Latest Movies"
        case .latestShows: return "Latest Shows"
        }
    }
}

/// A single horizontally scrolling recommendation row.
fileprivate struct DashboardRow: View {
    /// Which row this is, supplying both the heading and the cache key
    let rowType: HomeRow
    /// Streaming service used for card artwork
    let streamingService: RecommendationProviding & MediaImageProviding
    /// Shared cache owned by `HomeView`. Checked before fetching, and written to after
    @Binding var cache: [String: [MediaModelRepresentable]]
    /// App navigation, forwarded to each media card
    @Binding var navigation: NavigationPath
    /// Fetches this row's media. Only called on a cache miss
    let fetchMedia: () async -> [MediaModelRepresentable]

    /// Progress of this row's fetch
    @State private var status: DashboardRowStatus = .unstarted

    @Environment(ThemeModel.self) private var theme

    var body: some View {
        VStack(alignment: .leading) {
            switch status {
            case .empty:
                EmptyView()
            default:
                Text(self.rowType.name)
                    .font(.title2.bold())
                    .foregroundStyle(self.theme.currentTheme.header1)
                    .task {
                        // Check if we already have cached data
                        if let cachedMedia = cache[self.rowType.id] {
                            status = cachedMedia.isEmpty ? .empty : .complete(cachedMedia)
                            return
                        }

                        // Only fetch if not cached
                        let response = await fetchMedia()
                        cache[self.rowType.id] = response
                        status = response.isEmpty ? .empty : .complete(response)
                    }
            }

            switch status {
            case .unstarted, .retrieving:
                MediaNavigationLoadingPicker()
            case .complete(let newMedia):
                MediaPicker(streamingService: self.streamingService, pickerMedia: newMedia, navigation: $navigation)
            case .empty:
                EmptyView()
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Progress of a row's media fetch
    enum DashboardRowStatus {
        /// The fetch has not been kicked off yet
        case unstarted
        /// The fetch is in flight
        case retrieving
        /// Media is available and ready to display
        case complete([MediaModelRepresentable])
        /// The fetch finished with nothing to show, so the whole row is hidden
        case empty
    }
}

/// A horizontal strip of media cards for one populated dashboard row.
fileprivate struct MediaPicker: View {
    /// Streaming service used for card artwork
    var streamingService: MediaImageProviding
    /// Media to lay out, in the order the server returned it
    let pickerMedia: [MediaModelRepresentable]

    /// App navigation, forwarded to each media card
    @Binding var navigation: NavigationPath

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(pickerMedia) { media in
                    MediaCard(media: media, streamingService: self.streamingService, navigation: $navigation)
                }
            }
        }
    }
}

/// Resolves a media ID into the matching detail view. Because libraries stream in over time, a lookup that fails now may succeed later, so
/// a miss shows a spinner until every library has finished downloading.
public struct MediaDetailLoader: View {
    /// Server ID of the media to open
    public let mediaID: String
    /// Library the media is expected to live in, checked first to avoid scanning every library
    public let parentID: String?
    /// Streaming service used to look the media up and load its artwork
    public let streamingService: MediaImageProviding & MediaProviding & PlayerProviding

    /// App navigation, forwarded to the resolved detail view
    @Binding public var navigation: NavigationPath

    public var body: some View {
        switch self.streamingService.lookup(mediaID: self.mediaID, parentID: self.parentID) {
        case .found(let foundMedia):
            switch foundMedia.mediaType {
            case .tv(let seasons): TVShowDetailView(
                media: foundMedia,
                streamingService: self.streamingService,
                seasons: seasons,
                navigation: $navigation
            )
            case .movies(let movies): MovieDetailView(
                media: foundMedia,
                streamingService: self.streamingService,
                mediaSources: movies,
                navigation: $navigation
            )
            case .error(let error): ErrorView(error: error, summary: String(localized: "Failed to load media"))
            }
        case .temporarilyNotFound:
            ProgressView("Loading libraries...")
        case .notFound:
            Text("Media Not Found")
            Text("It may not have been compatible with Stingray")
                .foregroundStyle(.tertiary)
        }
    }
}

/// Placeholder row shown while a dashboard row is still fetching.
fileprivate struct MediaNavigationLoadingPicker: View {
    /// Number of placeholder cards. Randomized so the skeleton doesn't imply a known result count
    private let numOfPlaceholders: Int = Int.random(in: 4..<8)
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(0..<numOfPlaceholders, id: \.self) { index in
                    MediaNavigationLoadingCard()
                        .opacity(Double(1 - (Double(index) / Double(numOfPlaceholders))))
                }
            }
        }
    }
}

/// A single non-focusable placeholder card standing in for a media card that hasn't loaded.
public struct MediaNavigationLoadingCard: View {
    public var body: some View {
        Button {

        } label: {
            VStack {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView()
                }
                Text(
                    (3...5).map { _ in
                        String(repeating: "▀", count: Int.random(in: 2...5))
                    }
                        .joined(separator: " ")
                )
                .opacity(0.5)
                Spacer()
            }
            .frame(width: 200, height: 370)
        }
        .buttonStyle(.card)
        .focusable(false)
    }
}

/// A single line of build and hardware versions: Stingray, the Jellyfin server, tvOS, and the Apple TV model.
public struct SystemInfoView: View {
    /// Streaming service supplying the server's name and version
    public let streamingService: any SystemInfoProviding

    public var body: some View {
        // Display Stingray and Jellyfin server versions
        HStack(alignment: .center, spacing: 0) {
            if let stingrayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {  // Stingray
                Text("Stingray v\(stingrayVersion)")
            }
            else { Text("Unknown Stingray Version") }
            // Jellyfin
            Text(" • " + "Jellyfin Server ")
            if let name = self.streamingService.serverName { Text("\"\(name)\" ") }
            if let version = self.streamingService.serverVersion { Text("v\(version)") }
            // tvOS version
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            Text(" • " + "tvOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
            // Apple TV model
            Text(" • " + AppleTVCapabilities.current.hardwareModel)
        }
        .foregroundStyle(.tertiary)
    }
}

/// A single line summarizing library counts, with a spinner while libraries are still downloading.
public struct LibrariesInfoView: View {
    /// Streaming service containing libraries
    public let streamingService: LibraryProviding

    public var body: some View {
        switch self.streamingService.libraryStatus {
        case .retrieving: Text(String(localized: "Getting libraries..."))
        case .available(let libraries), .complete(let libraries):
            let mediaCounts = countMedia(libraries: libraries)
            HStack(spacing: 0) {
                if case .complete = self.streamingService.libraryStatus {
                    Text(String(localized: "Libraries: \(libraries.count)"))
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView()
                    Text(" " + String(localized: "Libraries: \(libraries.count)"))
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(mediaCounts.keys.sorted()), id: \.self) { key in
                    Text(" • " + "\(key): \(mediaCounts[key] ?? 0)")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 30)
        case .error(let rError): ErrorView(error: rError, summary: "Failed to load libraries")
        }
    }

    /// Counts all the media for each type.
    /// - Parameter libraries: Libraries to count with
    /// - Returns: Found media types and their associated counts
    public func countMedia(libraries: [LibraryModel]) -> [String : Int] {
        var counters: [String : Int] = [:]

        for library in libraries {
            switch library.media {
            case .waiting, .error: continue
            case .available(let medias):
                for media in medias {
                    switch media.mediaType {
                    case .movies:
                        counters["Movies", default: 0] += 1
                    case .tv:
                        counters["TV Shows", default: 0] += 1
                    case .error: continue
                    }
                }
            }
        }
        return counters
    }
}
