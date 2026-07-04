//
//  SearchView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/12/25.
//

import SwiftUI

public struct SearchView: View {
    public var streamingService: LibraryProviding & MediaImageProviding

    @Environment(SettingsModel.self) private var settings: SettingsModel

    @State private var searchText: String = ""
    @State private var searchResults: SearchStatus = .empty
    @Binding public var navigation: NavigationPath

    public var body: some View {
        ScrollView {
            switch searchResults {
            case .found(let allMedia):
                MediaGridView(allMedia: allMedia, streamingService: self.streamingService, navigation: $navigation)
            case .temporarilyNotFound:
                ProgressView("Not found yet, but we're still getting your media...")
            case .notFound:
                Text("No results for \"\(self.searchText)\"")
            case .empty:
                EmptyView()
            }
        }
        .searchable(text: $searchText)
        .onChange(of: self.searchText) {
            self.searchResults = search()
        }
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
                                            if score == 0 { break }// If it's not already a perfect match, search more episodes
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
extension String {
    /// A sliding Levenshtein Distance calculator, designed to give long names no disadvantage. For example searching for "Assass"
    /// will have a perfect result against "Assassination Classroom" since the full title is truncated to the length of the original search
    /// term. 0 = a perfect match, >0 = an imperfect match.
    /// - Parameter structuredTarget: String to compare against. The `structuredTarget` string dictates the length to check against.
    public func slidingLevenshteinDistance(to structuredTarget: String) -> Int {
        // Normalize both strings
        let selfLower = self.lowercased()
        let targetLower = structuredTarget.lowercased()
        
        // Short circuit if they're identical
        if selfLower == targetLower { return 0 }
        
        let targetChars = Array(targetLower)
        let sourceChars = Array(selfLower.prefix(targetChars.count))
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
