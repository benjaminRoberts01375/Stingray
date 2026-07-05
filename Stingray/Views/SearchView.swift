//
//  SearchView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/12/25.
//

import SwiftUI

public struct SearchView: View {
    public var streamingService: LibraryProviding & MediaImageProviding
    public let availableGenres: Set<String>
    /// Live search results
    private var searchResults: SearchStatus { search() }

    @Environment(SettingsModel.self) private var settings: SettingsModel

    @State private var searchText: String
    @Binding public var navigation: NavigationPath

    public init(
        streamingService: LibraryProviding & MediaImageProviding,
        navigation: Binding<NavigationPath>
    ) {
        self._navigation = navigation
        self.streamingService = streamingService
        self.searchText = ""

        switch self.streamingService.libraryStatus {
        case .available(let libraries), .complete(let libraries):
            var genres: Set<String> = []
            for library in libraries {
                genres.formUnion(library.genres)
            }
            self.availableGenres = genres
        default: self.availableGenres = []
        }
    }

    public var body: some View {
        ScrollView {
            switch searchResults {
            case .found(let allMedia):
                FilteredMediaGridView(
                    availableGenres: self.availableGenres,
                    streamingService: self.streamingService,
                    allMedia: allMedia,
                    navigation: $navigation
                )
            case .temporarilyNotFound:
                ProgressView("Not found yet, but we're still getting your media...")
            case .notFound:
                Text("No results for \"\(self.searchText)\"")
            case .empty:
                EmptyView()
            }
        }
        .searchable(text: $searchText)
    }

    /// Search results
    public enum SearchStatus {
        /// Found search results
        case found([any MediaProtocol])
        /// None were found, but some may be found soon
        case temporarilyNotFound
        /// Nothing was found, and nothing will be found
        case notFound
        /// No search attempt has been made
        case empty
    }

    public func search() -> SearchStatus {
        if self.searchText.isEmpty { return .empty }
        var scoredMedia: [MediaScore] = []

        switch self.streamingService.libraryStatus {
        case .error:
            return .notFound
        case .waiting, .retrieving:
            return .temporarilyNotFound
        case .available(let libraries), .complete(let libraries):
            let libraries = libraries.compactMap(\.media)
            for library in libraries {
                switch library {
                case .available(let medias), .complete(let medias):
                    scoredMedia += medias
                        .map {
                            var score: Int
                            var sortTitle = $0.title
                            if $0.title.lowercased().contains(self.searchText.lowercased()) { score = 0 }
                            else { score = $0.title.slidingLevenshteinDistance(to: self.searchText) }

                            // If it's not already a perfect match, search the episodes if there are any
                            if score != 0 && self.settings.searchEpisodeTitles {
                                switch $0.mediaType {
                                case .tv(let seasons):
                                    guard let seasons = seasons else { return MediaScore(media: $0, score: score, sortTitle: $0.title)}
                                    for season in seasons {
                                        for episode in season.episodes {
                                            score = min(score, episode.title.slidingLevenshteinDistance(to: self.searchText))
                                            sortTitle = episode.title
                                            if score == 0 { break } // If it's not already a perfect match, search more episodes
                                        }
                                        if score == 0 { break } // If it's not already a perfect match, search more episodes
                                    }
                                default: return MediaScore(media: $0, score: score, sortTitle: $0.title)
                                }
                            }
                            return MediaScore(media: $0, score: score, sortTitle: sortTitle)
                        }
                        .filter { $0.score <= 2 && $0.sortTitle.count >= self.searchText.count }
                default: break
                }
            }
        }

        if scoredMedia.isEmpty { return .notFound }

        let finalMedia = scoredMedia
            .sorted { $0.score < $1.score }
            .map { $0.media }

        return .found(finalMedia)
    }
}

/// Extend the String type to include a slidingLevenshteinDistance calculator
fileprivate extension String {
    /// A sliding Levenshtein Distance calculator, designed to give long names no disadvantage.
    ///
    /// For example, searching for "Assass" will have a perfect result against "Assassination Classroom" since the full title is truncated
    /// to the length of the original search term.
    /// `0` = a perfect match, `>0` = an imperfect match.
    ///
    /// ## Example
    /// Comparing "TASE" against "BACK":
    /// ```
    ///     B A C K
    ///   0 1 2 3 4
    /// T 1 1 2 3 4
    /// A 2 2 1 2 3
    /// S 3 3 2 2 3
    /// E 4 4 3 3 3
    /// ```
    ///
    /// 1. The grid is first populated with numbers 0-4 across the first row and column.
    /// 2. Work rows then go down a column.
    /// 3. Compare T vs B at (1,1). Take the minimum value from the surroundings (0, 1, 1), and add 1 since T and B differ. Thus 0 + 1 = 1.
    /// 4. Compare T vs A at (1,2). Take the minimum value from the surroundings (1, 1, 2), and add 1 since T and A differ. Thus 1 + 1 = 2.
    /// 5. Skipping ahead, compare A vs A at (2,2). Since the characters match, pull directly from the diagonal (1) with no added cost.
    /// 6. Once the matrix is filled out, the bottom-right value is the score, where lower indicates greater similarity.
    ///
    /// ## Notes
    /// - Diagonal: same character (match, cost 0) or different character (substitution, cost 1).
    /// - Taking from above indicates a deletion.
    /// - Taking from the left indicates an insertion.
    ///
    /// - Parameter structuredTarget: String to compare against. The `structuredTarget` string dictates the length to check against.
    /// - Returns: The edit distance score. Lower values indicate greater similarity; `0` is a perfect match.
    func slidingLevenshteinDistance(to structuredTarget: String) -> Int {
        // Normalize both strings
        let selfLower = self.lowercased()
        let targetLower = structuredTarget.lowercased()

        // Short circuit if they're identical
        if selfLower == targetLower { return 0 }

        let targetChars = Array(targetLower)
        let sourceChars = Array(selfLower.prefix(targetChars.count)) // Shorten string to be the same length as compared string
        let length = min(sourceChars.count, targetChars.count)

        // Short circuit if the search term is blank
        if length == 0 { return 0 }

        // This Levenshtein Distance calculator is heavily optimized to only keep two rows of the matrix in memory at a time
        var previousRow = Array(0...length)
        var currentRow = Array(repeating: 0, count: length + 1)

        for i in 1...length {
            currentRow[0] = i

            for j in 1...length {
                let cost = sourceChars[j - 1] == targetChars[i - 1] ? 0 : 1
                currentRow[j] = Swift.min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[length]
    }
}

/// Scores a piece of media based on the sortTitle for searching
public struct MediaScore {
    /// Associated media
    public let media: any MediaProtocol
    /// Score of the media
    public let score: Int
    /// Title the score is based on
    public let sortTitle: String
}
