//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

public struct DashboardView: View {
    public var streamingService: StreamingServiceProtocol
    @State private var selectedTab: String = "home"
    @State private var lastLoadedUserID: String?
    @Binding public var navigationPath: NavigationPath
    @Binding public var deepLinkRequest: DeepLinkRequest?
    @Binding public var loggedIn: LoginState
    
    public var body: some View {
        VStack {
            switch streamingService.libraryStatus {
            case .waiting, .retrieving: ProgressView()
            case .error(let err):
                VStack {
                    Text("Failed to Load Libraries")
                        .font(.title)
                        .bold()
                    Spacer()
                    ProfilePickerView(loginState: self.$loggedIn)
                        .padding(.vertical)
                    ErrorView(error: err, summary: "The server formatted the library's metadata unexpectedly.")
                        .padding(.vertical)
                    SystemInfoView(streamingService: streamingService)
                    Spacer()
                }
            case .available(let libraries), .complete(let libraries):
                TabView(selection: $selectedTab) {
                    Tab(value: "users") {
                        SettingsView(loginState: $loggedIn, streamingService: self.streamingService)
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
        .navigationDestination(for: MediaModelRepresentable.self) { representableMedia in
            MediaDetailLoader(
                mediaID: representableMedia.id,
                parentID: representableMedia.parentID,
                streamingService: streamingService,
                navigation: $navigationPath
            )
        }
        .navigationDestination(for: AnyMedia.self) { anyMedia in
            switch anyMedia.media.mediaType {
            case .tv(let seasons): TVShowDetailView(
                media: anyMedia.media,
                streamingService: streamingService,
                seasons: seasons ?? [],
                navigation: $navigationPath
            )
            case .movies(let movies): MovieDetailView(
                media: anyMedia.media,
                streamingService: streamingService,
                mediaSources: movies,
                navigation: $navigationPath
            )
            }
        }
        .onChange(of: deepLinkRequest) { _, newValue in
            guard let request = newValue else { return }
            navigationPath.append(request) // Navigate to requested media
            deepLinkRequest = nil // Clear the request
        }
        .onChange(of: self.streamingService.userID, initial: true) { _, newValue in
            // Only load if this is the first time (initial) or the user ID actually changed
            if self.lastLoadedUserID != newValue {
                self.lastLoadedUserID = newValue
                self.selectedTab = "home"
                Task { await self.streamingService.retrieveLibraries() }
            }
        }
        .task { // Handles case where the user might re-signin
            guard case .waiting = self.streamingService.libraryStatus
            else { return }
            self.selectedTab = "home"
            await self.streamingService.retrieveLibraries()
        }
    }
}

/// A type-erased wrapper for MediaProtocol that conforms to Hashable
public struct AnyMedia: Hashable {
    public let media: any MediaProtocol
    
    public static func == (lhs: AnyMedia, rhs: AnyMedia) -> Bool {
        lhs.media.id == rhs.media.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
    }
}
