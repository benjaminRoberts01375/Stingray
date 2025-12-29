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
    @Binding var loggedIn: LoginState
    
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
                        Tab(value: "users") {
                            UserView(streamingService: streamingService, loggedIn: $loggedIn)
                        } label: {
                            Text(streamingService.usersName)
                        }
                        
                        Tab(value: "search") {
                            SearchView(streamingService: streamingService, navigation: $navigationPath)
                        } label: {
                            Text("Search")
                        }
                        Tab(value: "home") {
                            ScrollView {
                                HomeView(streamingService: streamingService, navigation: $navigationPath)
                                    .scrollClipDisabled()
                            }
                        } label: {
                            Text("Home")
                        }
                        ForEach(libraries.indices, id: \.self) { index in
                            Tab(value: libraries[index].id) {
                                LibraryView(library: libraries[index], navigation: $navigationPath, streamingService: streamingService)
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
                    streamingService: streamingService,
                    navigation: $navigationPath
                )
            }
            .navigationDestination(for: SlimMedia.self) { slimMedia in
                MediaDetailLoader(
                    mediaID: slimMedia.id,
                    parentID: slimMedia.parentID,
                    streamingService: streamingService,
                    navigation: $navigationPath
                )
            }
            .navigationDestination(for: AnyMedia.self) { anyMedia in
                DetailMediaView(media: anyMedia.media, streamingService: streamingService, navigation: $navigationPath)
            }
        }
        .onChange(of: deepLinkRequest) { _, newValue in
            guard let request = newValue else { return }
            navigationPath.append(request) // Navigate to requested media
            deepLinkRequest = nil // Clear the request
        }
        .onChange(of: streamingService.userID, initial: true) {
            self.selectedTab = "home"
            Task { await streamingService.retrieveLibraries() }
        }
    }
}

/// A type-erased wrapper for MediaProtocol that conforms to Hashable
struct AnyMedia: Hashable {
    let media: any MediaProtocol
    
    static func == (lhs: AnyMedia, rhs: AnyMedia) -> Bool {
        lhs.media.id == rhs.media.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
    }
}
