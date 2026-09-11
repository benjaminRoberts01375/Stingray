//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

/// The signed-in shell: a tab per library alongside the settings, search, and home tabs.
///
/// Also owns every `navigationDestination` for media, so both deep links and in-app cards resolve to a detail view from here.
public struct DashboardView: View {
    /// Streaming service backing every tab
    public var streamingService: UserProviding & LibraryProviding & SystemInfoProviding & MediaImageProviding & MediaProviding &
    PlayerProviding & RecommendationProviding
    /// Selected tab. Holds either a fixed name or a library ID
    @State private var selectedTab: String = "home"
    /// App navigation, shared with every tab and detail view
    @Binding public var navigationPath: NavigationPath
    /// A pending deep link. Appended to the navigation path and then cleared
    @Binding public var deepLinkRequest: DeepLinkRequest?
    /// Login state, so the settings tab can sign the user out or switch profiles
    @Binding public var loggedIn: LoginState

    /// Currently signed-in user
    public let user: UserProtocol
    /// Location where all users are stored
    public let userModel: UserModelProtocol

    @Environment(SettingsModel.self) public var settings: SettingsModel

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
                    ProfilePickerView(loginState: $loggedIn, userModel: self.userModel)
                        .padding(.vertical)
                    VStack(alignment: .center) {
                        ErrorView(error: err, summary: "The server formatted the library's metadata unexpectedly.")
                        HStack(alignment: .center) {
                            NavigationLink { AddServerView(loginState: $loggedIn, userModel: self.userModel) }
                            label: { Text("Update Login...") }
                            Button {
                                switch self.user.serviceType {
                                case .Jellyfin(let userJellyfin):
                                    self.loggedIn = .loggedIn(
                                        JellyfinModel(
                                            userDisplayName: self.user.displayName,
                                            userID: self.user.id,
                                            serviceID: self.user.serviceID,
                                            accessToken: userJellyfin.accessToken,
                                            sessionID: userJellyfin.sessionID,
                                            serviceURL: self.user.serviceURL
                                        ), self.user
                                    )
                                }
                            }
                                label: { Text("Retry") }
                        }
                    }
                    .padding(.vertical)
                    Spacer()
                    SystemInfoView(streamingService: self.streamingService)
                }
            case .available(let libraries), .complete(let libraries):
                TabView(selection: $selectedTab) {
                    Tab(value: "users") {
                        SettingsView(
                            loginState: $loggedIn,
                            userModel: self.userModel,
                            user: self.user,
                            streamingService: self.streamingService
                        )
                    }
                    label: { Text(self.streamingService.usersName) }

                    Tab(value: "search") { SearchView(streamingService: self.streamingService, navigation: $navigationPath) }
                    label: { Text("Search") }
                    Tab(value: "home") {
                        ScrollView {
                            HomeView(streamingService: self.streamingService, navigation: $navigationPath)
                                .scrollClipDisabled()
                        }
                    }
                    label: { Text("Home") }
                    ForEach(libraries.indices, id: \.self) { index in
                        Tab(value: libraries[index].id) {
                            LibraryView(library: libraries[index], navigation: $navigationPath, streamingService: self.streamingService)
                        }
                        label: { Text(libraries[index].title) }
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
            case .tv(let seasonsAvailable):
                TVShowDetailView(
                    media: anyMedia.media,
                    streamingService: self.streamingService,
                    seasons: seasonsAvailable,
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
/// `NavigationPath` requires concrete `Hashable` values, which `any MediaProtocol` can't satisfy on its own.
public struct AnyMedia: Hashable {
    /// The wrapped media. Identity is its `id` alone
    public let media: any MediaProtocol

    public static func == (lhs: AnyMedia, rhs: AnyMedia) -> Bool {
        lhs.media.id == rhs.media.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
    }
}
