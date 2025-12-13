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
    
    public var body: some View {
        VStack {
            switch searchResults {
            case .found(let allMedia):
                ScrollView {
                    MediaGridView(allMedia: allMedia, streamingService: streamingService)
                }
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
                        .map { MediaScore(media: $0, score: $0.title.slidingLevenshteinDistance(to: searchText)) }
                        .filter { $0.media.title.count >= searchText.count && $0.score <= 2 }
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
        if self.lowercased() == structuredTarget.lowercased() { return 0 }
        
        let target = Array(structuredTarget.lowercased()) // Normalized
        let source = Array(self.lowercased()).prefix(target.count) // Normalized
        let length = min(source.count, target.count)
        
        // Make a 2D SQUARE matrix based on the length of the target (search text)
        var matrix = [[Int]](
            repeating: [Int](
                repeating: 0,
                count: length + 1
            ),
            count: length + 1
        )
        
        // Fill-in base values of matrix
        for i in 0...length {
            matrix[i][0] = i
            matrix[0][i] = i
        }
        
        // Walk the entire graph calculating distances
        for i in 1...(length) {
            for j in 1...(length) {
                let cost = source[j - 1] == target[i - 1] ? 0 : 1 // Offset by 1 to account for the edges of the matrix
                matrix[i][j] = Swift.min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        return matrix[length][length]
    }
}

struct MediaScore {
    let media: any MediaProtocol
    let score: Int
}
