//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

public struct DashboardView: View {
    public var streamingService: UserProviding & LibraryProviding & SystemInfoProviding & MediaImageProviding & MediaProviding &
    PlayerProviding & RecommendationProviding
    @State private var selectedTab: String = "home"
    @Binding public var navigationPath: NavigationPath
    @Binding public var deepLinkRequest: DeepLinkRequest?
    @Binding public var loggedIn: LoginState

    public var body: some View {
        VStack {
            switch self.streamingService.libraryStatus {
            case .retrieving: ProgressView()
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
                    SystemInfoView(streamingService: self.streamingService)
                    Spacer()
                }
            case .available(let libraries), .complete(let libraries):
                TabView(selection: $selectedTab) {
                    Tab(value: "users") {
                        SettingsView(loginState: $loggedIn, streamingService: self.streamingService)
                    } label: {
                        Text(self.streamingService.usersName)
                    }

                    Tab(value: "search") {
                        SearchView(streamingService: self.streamingService, navigation: $navigationPath)
                    } label: {
                        Text("Search")
                    }
                    Tab(value: "home") {
                        ScrollView {
                            HomeView(streamingService: self.streamingService, navigation: $navigationPath)
                                .scrollClipDisabled()
                        }
                    } label: {
                        Text("Home")
                    }
                    ForEach(libraries.indices, id: \.self) { index in
                        Tab(value: libraries[index].id) {
                            LibraryView(library: libraries[index], navigation: $navigationPath, streamingService: self.streamingService)
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
                streamingService: self.streamingService,
                navigation: $navigationPath
            )
        }
        .navigationDestination(for: MediaModelRepresentable.self) { representableMedia in
            MediaDetailLoader(
                mediaID: representableMedia.id,
                parentID: representableMedia.parentID,
                streamingService: self.streamingService,
                navigation: $navigationPath
            )
        }
        .navigationDestination(for: AnyMedia.self) { anyMedia in
            switch anyMedia.media.mediaType {
            case .tv(let seasons):
                TVShowDetailView(
                    media: anyMedia.media,
                    streamingService: self.streamingService,
                    seasons: seasons,
                    navigation: $navigationPath
                )
            case .movies(let movies):
                MovieDetailView(
                    media: anyMedia.media,
                    streamingService: self.streamingService,
                    mediaSources: movies,
                    navigation: $navigationPath
                )
            case .error(let error): ErrorView(error: error, summary: (String(localized: "Failed to load library")))
            }
        }
        .onChange(of: deepLinkRequest) { _, newValue in
            guard let request = newValue else { return }
            navigationPath.append(request) // Navigate to requested media
            deepLinkRequest = nil // Clear the request
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
