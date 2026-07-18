//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State public var library: any LibraryProtocol

    @Binding public var navigation: NavigationPath

    public let streamingService: MediaImageProviding
    public let cardWidth = CGFloat(200)
    public let cardSpacing = CGFloat(50)

    public var body: some View {
        ScrollView {
            switch library.media {
            case .waiting: ProgressView()
            case .error(let err): ErrorView(error: err, summary: "The server formatted the library's media unexpectedly.")
            case .available(let allMedia):
                if !allMedia.isEmpty {
                    FilteredMediaGridView(
                        availableGenres: self.library.genres,
                        availableMaturityRatings: self.library.maturityRatings,
                        streamingService: self.streamingService,
                        allMedia: allMedia,
                        navigation: $navigation
                    )
                    LibraryInfoView(library: self.library)
                        .padding(.top)
                } else {
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

public struct FilteredMediaGridView: View {
    public let availableGenres: Set<String>
    public let availableMaturityRatings: Set<String>
    public let streamingService: any MediaImageProviding
    public let allMedia: [any MediaRepresentableProtocol]
    @State private var appliedGenreFilters: Set<String> = []
    @State private var appliedMaturityRatingFilters: Set<String> = []
    @State private var sortBy: SortType = .sortTitle
    @State private var sortOrderAscending: Bool = true
    /// Seed for the random sort. Kept in state so the shuffle is stable across re-renders and only changes when Random is (re)selected.
    @State private var randomSeed: UInt64 = .random(in: .min ... .max)
    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings

    /// Media matching every applied genre filter. Computed so it always reflects the current`allMedia`
    private var filteredMedia: [any MediaRepresentableProtocol] {
        let filtered = self.allMedia
            .filter { model in
                if appliedGenreFilters.isEmpty { return true }
                // Keep only media that has every applied genre
                return self.appliedGenreFilters.allSatisfy { model.genres.contains($0) }
            }
            .filter { model in
                if self.appliedMaturityRatingFilters.isEmpty { return true }
                return self.appliedMaturityRatingFilters.contains(model.maturity ?? "")
            }

        // Random can't be expressed as a comparator (it would violate the strict weak ordering
        // sorted(by:) requires), so shuffle with a seeded generator for a stable, repeatable order.
        if self.sortBy == .random {
            var generator = SeededGenerator(seed: self.randomSeed)
            return filtered.shuffled(using: &generator)
        }

        // Create an on-the-fly sorting function
        let areInOrder: (any MediaRepresentableProtocol, any MediaRepresentableProtocol) -> Bool
        switch (self.sortBy, self.sortOrderAscending) {
        case (.sortTitle, true):  areInOrder = { $0.sortTitle < $1.sortTitle }
        case (.sortTitle, false): areInOrder = { $0.sortTitle > $1.sortTitle }
        case (.title, true): areInOrder = { $0.title < $1.title }
        case (.title, false): areInOrder = { $0.title > $1.title }
        case (.duration, true): areInOrder = { ($0.duration ?? .zero) < ($1.duration ?? .zero) }
        case (.duration, false): areInOrder = { ($0.duration ?? .zero) > ($1.duration ?? .zero) }
        case (.releaseDate, true): areInOrder = { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }
        case (.releaseDate, false): areInOrder = { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        case (.random, _): return filtered // Handled above
        }

        return filtered.sorted(by: areInOrder)
    }

    public var body: some View {
        HStack {
            if self.settings.showFilters {
                Menu {
                    // Clear action at the top, only when something is selected.
                    if !self.appliedGenreFilters.isEmpty {
                        Button(role: .destructive) {
                            self.appliedGenreFilters = []
                        }
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
                Menu {
                    if !self.appliedMaturityRatingFilters.isEmpty {
                        Button(role: .destructive) {
                            self.appliedMaturityRatingFilters = []
                        }
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
                Menu {
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
                if self.sortBy == .random {
                    Button { self.randomSeed = .random(in: .min ... .max) }
                    label: { Text("Reshuffle") }
                }
                else {
                    Button { self.sortOrderAscending.toggle() }
                    label: {
                        if self.sortOrderAscending { Text("Sort Order: Ascending") }
                        else { Text("Sort Order: Descending") }
                    }
                }
            }
        }
        .focusSection()

        MediaGridView(allMedia: self.filteredMedia, streamingService: self.streamingService, navigation: $navigation)
            .focusSection()
    }
}

fileprivate enum SortType: CaseIterable {
    case sortTitle
    case title
    case duration
    case releaseDate
    case random

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

public struct MediaGridView: View {
    public static let cardSpacing = 50.0
    public let allMedia: [any MediaRepresentableProtocol]
    public let streamingService: any MediaImageProviding

    @Binding public var navigation: NavigationPath

    private static let columns = [
        GridItem(.adaptive(minimum: MediaCard.cardSize.width, maximum: MediaCard.cardSize.width), spacing: Self.cardSpacing)
    ]

    public var body: some View {
        LazyVGrid(columns: Self.columns, spacing: Self.cardSpacing) {
            ForEach(allMedia, id: \.id) { media in
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
