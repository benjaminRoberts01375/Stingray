//
//  SearchView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/12/25.
//

import SwiftUI

public struct SearchView: View {
    var streamingService: StreamingServiceProtocol
    
    @State var searchText: String = ""
    @State var searchResults: SearchStatus = .empty
    @Binding var navigation: NavigationPath
    
    public var body: some View {
        ScrollView {
            switch searchResults {
            case .found(let allMedia):
                MediaGridView(allMedia: allMedia, streamingService: streamingService, navigation: $navigation)
            case .temporarilyNotFound:
                ProgressView("Not found yet, but we're still getting your media...")
            case .notFound:
                Text("No results for \"\(searchText)\"")
            case .empty:
                EmptyView()
            }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) {
            self.searchResults = search()
        }
    }
    
    /// Search results
    enum SearchStatus {
        /// Found search results
        case found([any MediaProtocol])
        /// None were found, but some may be found soon
        case temporarilyNotFound
        /// Nothing was found, and nothing will be found
        case notFound
        /// No search attempt has been made
        case empty
    }
    
    func search() -> SearchStatus {
        if searchText.isEmpty { return .empty }
        var scoredMedia: [MediaScore] = []
        
        switch streamingService.libraryStatus {
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
                            if $0.title.lowercased().contains(searchText.lowercased()) { score = 0 }
                            else { score = $0.title.slidingLevenshteinDistance(to: searchText) }
                            if score != 0 { // If it's not already a perfect match, search the episodes if there are any
                                switch $0.mediaType {
                                case .tv(let seasons):
                                    guard let seasons = seasons else { return MediaScore(media: $0, score: score, sortTitle: $0.title)}
                                    for season in seasons {
                                        for episode in season.episodes {
                                            score = min(score, episode.title.slidingLevenshteinDistance(to: searchText))
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
                        .filter { $0.score <= 2 && $0.sortTitle.count >= searchText.count }
                default: break
                }
            }
        }
        
        if scoredMedia.isEmpty {
            return .notFound
        }
        
        let finalMedia = scoredMedia
            .sorted { $0.score < $1.score }
            .map { $0.media }
        
        return .found(finalMedia)
    }
}

extension String {
    /// A sliding Levenshtein Distance calculator, designed to give long names no disadvantage. For example searching for "Assass"
    /// will have a perfect result against "Assassination Classroom" since the full title is truncated to the length of the original search
    /// term.
    /// - Parameter structuredTarget: String to compare against. The `structuredTarget` string dictates the length to check against.
    func slidingLevenshteinDistance(to structuredTarget: String) -> Int {
        let selfLower = self.lowercased()
        let targetLower = structuredTarget.lowercased()
        
        if selfLower == targetLower { return 0 }
        
        let targetChars = Array(targetLower)
        let sourceChars = Array(selfLower.prefix(targetChars.count))
        let length = min(sourceChars.count, targetChars.count)
        
        if length == 0 { return 0 }
        
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

struct MediaScore {
    let media: any MediaProtocol
    let score: Int
    let sortTitle: String
}
