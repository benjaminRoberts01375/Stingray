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
            case .unloaded, .waiting:
                ProgressView()
            case .error(let err):
                ErrorView(error: err, summary: "The server formatted the library's media unexpectedly.")
            case .available(let allMedia), .complete(let allMedia):
                if !allMedia.isEmpty {
                    FilteredMediaGridView(
                        availableGenres: self.library.genres,
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
    public let streamingService: any MediaImageProviding
    public let allMedia: [any MediaRepresentableProtocol]
    @State private var appliedGenreFilters: Set<String> = []
    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings

    /// Media matching every applied genre filter. Computed so it always reflects the current`allMedia`
    private var filteredMedia: [any MediaRepresentableProtocol] {
        self.allMedia.filter { mediaRepresentable in
            guard let model = mediaRepresentable as? any MediaProtocol // Filter out incomplete media
            else { return false }
            if appliedGenreFilters.isEmpty { return true } // Small efficiency gain
            // Keep only media that has every applied genre
            return self.appliedGenreFilters.allSatisfy { model.genres.contains($0) }
        }
    }

    public var body: some View {
        HStack {
            if self.settings.showFilters {
                Menu {
                    // Clear action at the top, only when something is selected.
                    if !appliedGenreFilters.isEmpty {
                        Button(role: .destructive) {
                            self.appliedGenreFilters = []
                        }
                        label: { Label("Remove all genre filters", systemImage: "xmark.circle") }
                        Divider()
                    }

                    ForEach(self.availableGenres.sorted(), id: \.self) { genre in
                        let genreIsSelected = appliedGenreFilters.contains(genre)
                        Button {
                            if genreIsSelected { appliedGenreFilters.remove(genre) }
                            else { appliedGenreFilters.insert(genre) }
                        }
                        label: { Label(genre, systemImage: genreIsSelected ? "checkmark" : "") }
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
            }
        }
        .focusSection()

        MediaGridView(allMedia: self.filteredMedia, streamingService: self.streamingService, navigation: $navigation)
            .focusSection()
    }
}

public struct MediaGridView: View {
    public static let cardSpacing = 50.0
    public let allMedia: [any MediaRepresentableProtocol]
    public let streamingService: any MediaImageProviding

    @Binding public var navigation: NavigationPath

    private static let columns = [
        GridItem(.adaptive(minimum: MediaCard.cardSize.width, maximum: MediaCard.cardSize.height), spacing: Self.cardSpacing)
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
            switch self.library.media { // Only display a ProgressView while downloading content.
            case .waiting, .unloaded, .available: ProgressView()
            default: EmptyView()
            }
            
            switch self.library.media {
            case .available(let media), .complete(let media): Text("\(media.count) Items")
            default: Text("0 Items")
            }
        }
        .foregroundStyle(.tertiary)
    }
}
