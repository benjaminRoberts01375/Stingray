//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

/// One library tab: a filterable, sortable grid of its media with a refresh button.
public struct LibraryView: View {
    /// Library being displayed. Media streams into it while the view is open
    public let library: any LibraryProtocol

    /// App navigation, forwarded to each media card
    @Binding public var navigation: NavigationPath

    /// Streaming service used for artwork and for resyncing the library
    public let streamingService: MediaImageProviding & LibraryProviding

    /// Settings for deciding whether sub-folders get flattened on refresh
    @Environment(SettingsModel.self) private var settings

    public var body: some View {
        ScrollView {
            switch self.library.media {
            case .waiting: ProgressView()
            case .error(let err): ErrorView(error: err, summary: "The server formatted the library's media unexpectedly.")
            case .available(let allMedia):
                if !allMedia.isEmpty {
                    FilteredMediaGridView(
                        availableGenres: self.library.genres,
                        availableMaturityRatings: self.library.maturity,
                        streamingService: self.streamingService,
                        allMedia: allMedia,
                        navigation: $navigation
                    ) {
                        Button {
                            Task { await self.streamingService.resync(library: self.library, flatten: self.settings.flattenFolders) }
                        }
                        label: { Text(String(localized: "Refresh")) }

                    }
                    LibraryInfoView(library: self.library)
                        .padding(.top)
                }
                else {
                    VStack(alignment: .center) {
                        Text("This library appears to be empty.")
                        Text("Media types like collections, playlists, and music aren't yet supported.")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

/// A media grid preceded by a scrolling row of filter, sort, and caller-supplied buttons. Filtering and sorting happen here rather than on
/// the server, since all media is already local.
public struct FilteredMediaGridView<ButtonContent: View>: View {
    /// Every genre available to filter by
    public let availableGenres: Set<String>
    /// Every maturity rating available to filter by
    public let availableMaturityRatings: Set<String>
    /// Streaming service used for card artwork
    public let streamingService: any MediaImageProviding
    /// Unfiltered, unsorted media. `filteredMedia` derives the displayed list from it
    private let allMedia: [MediaStorageSection]
    /// Extra buttons appended to the button row, ex. the library refresh button
    public var additionalButtons: () -> ButtonContent
    /// Selected genres. Media must match every one of them
    @State private var appliedGenreFilters: Set<String> = []
    /// Selected maturity ratings. Media must match any one of them
    @State private var appliedMaturityRatingFilters: Set<String> = []
    /// Field currently sorted on
    @State private var sortBy: SortType = .sortTitle
    /// Sort direction. Ignored when sorting randomly
    @State private var sortOrderAscending: Bool = true
    /// Seed for the random sort. Kept in state so the shuffle is stable across re-renders and only changes when Random is (re)selected.
    @State private var randomSeed: UInt64 = .random(in: .min ... .max)

    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme

    /// Width of the button row's scroll view. A `ScrollView` proposes an unbounded width to its content, so the
    /// visible width has to be measured and fed back in as a minimum to keep short rows centered.
    @State private var buttonRowContainerWidth: CGFloat = 0

    /// Media matching every applied filter, in the selected order. Computed so it always reflects the current `allMedia`
    private var filteredMedia: [MediaStorageSection] {
        var sortedMedia: [MediaStorageSection] = []
        for media in self.allMedia {
            sortedMedia
                .append(
                    media
                        .filterAndSort(
                            sortBy: self.sortBy,
                            appliedGenreFilters: self.appliedGenreFilters,
                            appliedMaturityRatingFilters: self.appliedMaturityRatingFilters,
                            randomSeed: self.randomSeed,
                            sortOrderAscending: self.sortOrderAscending
                        )
                )
        }
        return sortedMedia
    }

    /// A convienent way of storing, sorting, and filtering media
    private struct MediaStorageSection: Identifiable {
        /// Items to of this type
        public private(set) var items: [MediaStorage]
        /// There should be one `MediaType` per `MediaStorageSection`
        public var id: MediaStorage.MediaType

        /// Create a `MediaStorageSection` with known items
        /// - Parameters:
        ///   - items: Items to store
        ///   - id: Media type the items are
        public init(items: [MediaStorage], id: MediaStorage.MediaType) {
            self.items = items
            self.id = id
        }

        /// Applies the current genre and maturity filters, then the current sort, to some media.
        /// - Parameter media: Unfiltered, unsorted media
        /// - Returns: The filtered and sorted media
        public func filterAndSort(
            sortBy: SortType,
            appliedGenreFilters: Set<String>,
            appliedMaturityRatingFilters: Set<String>,
            randomSeed: UInt64,
            sortOrderAscending: Bool
        ) -> MediaStorageSection {
            var filtered = self.items
            if !appliedGenreFilters.isEmpty {
                // Keep only media that has every applied genre
                filtered = filtered.filter { model in
                    appliedGenreFilters.allSatisfy { model.genres?.contains($0) ?? false }
                }
            }
            if !appliedMaturityRatingFilters.isEmpty {
                // Keep only media that has every applied maturity
                filtered = filtered.filter { model in
                    appliedMaturityRatingFilters.contains(model.mediaMetadata?.maturity ?? "")
                }
            }

            // Random can't be expressed as a comparator (it would violate the strict weak ordering
            // sorted(by:) requires), so shuffle with a seeded generator for a stable, repeatable order.
            if sortBy == .random {
                var generator = SeededGenerator(seed: randomSeed)
                return MediaStorageSection(items: filtered.shuffled(using: &generator), id: self.id)
            }

            // Create an on-the-fly sorting function
            let areInOrder: (MediaStorage, MediaStorage) -> Bool
            switch (sortBy, sortOrderAscending) {
            case (.sortTitle, true):  areInOrder = { ($0.sortTitle) < ($1.sortTitle) }
            case (.sortTitle, false): areInOrder = { ($0.sortTitle) > ($1.sortTitle) }
            case (.title, true): areInOrder = { ($0.title) < ($1.title) }
            case (.title, false): areInOrder = { ($0.title) > ($1.title) }
            case (.duration, true): areInOrder = { ($0.mediaMetadata?.duration ?? .zero) < ($1.mediaMetadata?.duration ?? .zero) }
            case (.duration, false): areInOrder = { ($0.mediaMetadata?.duration ?? .zero) > ($1.mediaMetadata?.duration ?? .zero) }
            case (.releaseDate, true):
                areInOrder = { ($0.mediaMetadata?.releaseDate ?? .distantPast) < ($1.mediaMetadata?.releaseDate ?? .distantPast) }
            case (.releaseDate, false):
                areInOrder = { ($0.mediaMetadata?.releaseDate ?? .distantPast) > ($1.mediaMetadata?.releaseDate ?? .distantPast) }
            case (.random, _): return MediaStorageSection(items: filtered, id: self.id) // Handled above
            }

            return MediaStorageSection(items: filtered.sorted(by: areInOrder), id: self.id)
        }
    }

    /// Display media in a grid
    /// - Parameters:
    ///   - availableGenres: All genres in the media
    ///   - availableMaturityRatings: All level of maturity in the media
    ///   - streamingService: Streaming service to load images from
    ///   - allMedia: Media to display. The leading divider is pre-calculated
    ///   - navigation: App navigation
    ///   - additionalButtons: Any additional buttons to show
    public init(
        availableGenres: Set<String>,
        availableMaturityRatings: Set<String>,
        streamingService: any MediaImageProviding,
        allMedia: [MediaStorage],
        navigation: Binding<NavigationPath>,
        @ViewBuilder additionalButtons: @escaping () -> ButtonContent = { EmptyView() }
    ) {
        self.availableGenres = availableGenres
        self.availableMaturityRatings = availableMaturityRatings
        self.additionalButtons = additionalButtons
        self.streamingService = streamingService
        self._navigation = navigation

        func rankMedia(_ mediaType: MediaStorage.MediaType) -> Int {
            switch mediaType {
            case .error: return 0
            case .example: return 1
            case .subFolder: return 2
            case .homeVideo: return 3
            case .movie: return 4
            case .episode: return 5
            case .tvShow: return 6
            }
        }

        var mediaGroups: [MediaStorageSection] = []
        for (mediaType, groupedMedia) in Dictionary(grouping: allMedia, by: \.mediaType) {
            mediaGroups.append(MediaStorageSection(items: groupedMedia, id: mediaType))
        }
        self.allMedia = mediaGroups.sorted(by: { rankMedia($0.id) < rankMedia($1.id) })
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                self.buttonRow
                // Centers the row when it fits, and lets it grow past the container (and scroll) when it doesn't. AI generated
                    .frame(minWidth: self.buttonRowContainerWidth)
            }
            .scrollClipDisabled()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { self.buttonRowContainerWidth = $0 }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .focusSection()
            ForEach(Array(self.filteredMedia.enumerated()), id: \.element.id) { index, mediaGroup in
                if self.filteredMedia.count > 1 { // Section titles
                    Text(mediaGroup.id.readablePlural)
                        .font(.title2.bold())
                        .foregroundStyle(self.theme.currentTheme.header1)
                }
                if index == self.filteredMedia.count - 1 {  // Main grid view
                    MediaGridView(
                        allMedia: mediaGroup.items,
                        streamingService: self.streamingService,
                        size: mediaGroup.id,
                        navigation: $navigation
                    )
                    .focusSection()
                }
                else { // Shelf
                    ScrollView(.horizontal) {
                        LazyHStack {
                            ForEach(mediaGroup.items, id: \.id) { mediaStore in
                                MediaCard(
                                    media: mediaStore,
                                    streamingService: self.streamingService,
                                    navigation: $navigation,
                                    scale: .shelf
                                )
                            }
                        }
                    }
                    .scrollClipDisabled()
                    .focusSection()
                }
            }
        }
    }

    @ViewBuilder private var buttonRow: some View {
        HStack(spacing: 25) {
            if self.settings.showFilters {
                Menu { // Genres
                    // Clear action at the top, only when something is selected.
                    if !self.appliedGenreFilters.isEmpty {
                        Button(role: .destructive) { self.appliedGenreFilters = [] }
                        label: { Label("Remove all genre filters", systemImage: "xmark.circle") }
                        Divider()
                    }

                    ForEach(self.availableGenres.sorted(), id: \.self) { genre in
                        let genreIsSelected = self.appliedGenreFilters.contains(genre)
                        Button {
                            if genreIsSelected { self.appliedGenreFilters.remove(genre) }
                            else { self.appliedGenreFilters.insert(genre) }
                        }
                        label: {
                            if genreIsSelected { Label(genre, systemImage: "checkmark") }
                            else { Text(genre) }
                        }
                    }
                }
                label: {
                    if self.appliedGenreFilters.isEmpty { Text("Genres") }
                    else {
                        Text("Genres: \(self.appliedGenreFilters.sorted().joined(separator: ", "))")
                            .frame(maxWidth: 400)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                Menu { // Maturity
                    if !self.appliedMaturityRatingFilters.isEmpty {
                        Button(role: .destructive) { self.appliedMaturityRatingFilters = [] }
                        label: { Label("Remove all maturity filters", systemImage: "xmark.circle") }
                        Divider()
                    }

                    ForEach(self.availableMaturityRatings.sorted(), id: \.self) { maturity in
                        let maturityIsSelected = self.appliedMaturityRatingFilters.contains(maturity)
                        Button {
                            if maturityIsSelected { self.appliedMaturityRatingFilters.remove(maturity) }
                            else { self.appliedMaturityRatingFilters.insert(maturity) }
                        }
                        label: {
                            if maturityIsSelected { Label(maturity, systemImage: "checkmark") }
                            else { Text(maturity) }
                        }
                    }
                }
                label: {
                    if self.appliedMaturityRatingFilters.isEmpty { Text("Maturity") }
                    else {
                        Text("Maturity: \(self.appliedMaturityRatingFilters.sorted().joined(separator: ", "))")
                            .frame(maxWidth: 400)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            if self.settings.showFilters && self.settings.showSorting { Divider() }
            if self.settings.showSorting {
                Menu { // Sort by
                    ForEach(SortType.allCases, id: \.self) { sortBy in
                        Button {
                            // Reshuffle every time Random is chosen, even if it's already selected.
                            if sortBy == .random { self.randomSeed = .random(in: .min ... .max) }
                            self.sortBy = sortBy
                        }
                        label: {
                            if sortBy == self.sortBy { Label(sortBy.rawValue, systemImage: "checkmark") }
                            else { Text(sortBy.rawValue) }
                        }
                    }
                }
                label: { Text("Sort By: \(self.sortBy.rawValue)") }
                if self.sortBy == .random { // Reshuffle
                    Button { self.randomSeed = .random(in: .min ... .max) }
                    label: { Text("Reshuffle") }
                }
                else { // Sort order
                    Button { self.sortOrderAscending.toggle() }
                    label: {
                        if self.sortOrderAscending { Text("Sort Order: Ascending") }
                        else { Text("Sort Order: Descending") }
                    }
                }
            }
            if (self.settings.showFilters || self.settings.showSorting) && ButtonContent.self != EmptyView.self { Divider() }
            self.additionalButtons()
        }
    }
}

/// Orderings offered by the library and search sort menu.
fileprivate enum SortType: CaseIterable {
    /// The server's sort title, which honors user-set aliases. The default
    case sortTitle
    /// The media's original title, ignoring aliases
    case title
    /// Runtime, or per-episode runtime for shows
    case duration
    /// Original release date
    case releaseDate
    /// Seeded shuffle. Ignores sort direction and is reshuffled on demand
    case random

    /// User-facing, localized menu label
    var rawValue: String {
        switch self {
        case .sortTitle: return String(localized: "Sort Title")
        case .title: return String(localized: "Title")
        case .duration: return String(localized: "Duration")
        case .releaseDate: return String(localized: "Release Date")
        case .random: return String(localized: "Random")
        }
    }
}

/// A deterministic random number generator so a random sort stays stable across re-renders for a given seed.
/// AI Generated
fileprivate struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid an all-zero state, which would produce a degenerate sequence.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        self.state &+= 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A lazily loaded, adaptive grid of media cards.
public struct MediaGridView: View {
    /// Gap between cards, horizontally and vertically
    public static let cardSpacing = 50.0
    /// Media to display, already filtered and sorted
    public let allMedia: [MediaStorage]
    /// Streaming service used for card artwork
    public let streamingService: any MediaImageProviding

    /// App navigation, forwarded to each media card
    @Binding public var navigation: NavigationPath

    /// Columns sized to exactly one card, so cards never stretch to fill the row
    private let columns: [GridItem]

    public init(
        allMedia: [MediaStorage],
        streamingService: any MediaImageProviding,
        size: MediaStorage.MediaType,
        navigation: Binding<NavigationPath>
    ) {
        self.allMedia = allMedia
        self.streamingService = streamingService
        self._navigation = navigation

        let gridSize = MediaCard.size(for: allMedia.first?.mediaType ?? .movie, size: .full).width
        self.columns = [GridItem(.adaptive(minimum: gridSize, maximum: gridSize), spacing: Self.cardSpacing)]
    }

    public var body: some View {
        LazyVGrid(columns: self.columns, spacing: Self.cardSpacing) {
            ForEach(self.allMedia, id: \.id) { media in
                MediaCard(media: media, streamingService: self.streamingService, navigation: $navigation)
            }
        }
        .scrollTargetLayout()
    }
}

/// Displays some high-level info about libraries.
public struct LibraryInfoView: View {
    /// Library to display info for.
    public let library: any LibraryProtocol

    public var body: some View {
        HStack(spacing: 0) {
            switch self.library.media {
            case .available(let media): Text("\(media.count) Items")
            default: Text("0 Items")
            }
        }
        .foregroundStyle(.tertiary)
    }
}
