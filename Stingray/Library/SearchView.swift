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
        var foundContent: [any MediaProtocol] = []
        
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
                    foundContent += medias.filter { $0.title.lowercased().contains(searchText) }
                default: break
                }
            }
        }
        
        if foundContent.isEmpty {
            return .notFound
        }
        return .found(foundContent)
    }
}
