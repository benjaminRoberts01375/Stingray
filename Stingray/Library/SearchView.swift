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
            case .found(let foundMedia):
                EmptyView()
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
        
        return .notFound
    }
}
