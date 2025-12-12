//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

struct DashboardView: View {
    var streamingService: StreamingServiceProtocol
    @State private var selectedTab: String = "home"
    @State private var navigationPath = NavigationPath()
    @Binding var deepLinkRequest: DeepLinkRequest?
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                switch streamingService.libraryStatus {
                case .waiting, .retrieving:
                    ProgressView()
                case .error(let err):
                    Text("Error loading libraries: \(err.localizedDescription)")
                        .foregroundStyle(.red)
                    
                case .available(let libraries), .complete(let libraries):
                    TabView(selection: $selectedTab) {
                        Tab(value: "search") {
                            SearchView(streamingService: streamingService)
                        } label: {
                            Text("Search")
                        }
                        Tab(value: "home") {
                            ScrollView {
                                HomeView(streamingService: streamingService)
                                    .scrollClipDisabled()
                            }
                        } label: {
                            Text("Home")
                        }
                        ForEach(libraries.indices, id: \.self) { index in
                            Tab(value: libraries[index].id) {
                                LibraryView(library: libraries[index], streamingService: streamingService)
                            } label: {
                                Text(libraries[index].title)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: DeepLinkRequest.self) { request in
                MediaDetailLoader(
                    mediaID: request.mediaID,
                    parentID: request.parentID,
                    streamingService: streamingService
                )
            }
        }
        .onChange(of: deepLinkRequest) { _, newValue in
            guard let request = newValue else { return }
            navigationPath.append(request) // Navigate to requested media
            deepLinkRequest = nil // Clear the request
        }
    }
}
