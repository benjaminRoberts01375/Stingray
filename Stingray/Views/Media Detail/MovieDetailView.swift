//
//  MovieDetailView.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import AVKit
import BlurHashKit
import SwiftUI

// MARK: Main view
public struct MovieDetailView: View {
    /// Media that contains content to play
    public let media: any MediaProtocol
    /// Streaming service the user is using
    public let streamingService: MediaImageProviding & PlayerProviding & MediaProviding
    /// All available content sources for this movie and its various versions
    public let mediaSources: [any MediaSourceProtocol]

    @Binding public var navigation: NavigationPath

    @State private var shouldBackgroundBlur: Bool = false
    @State private var shouldRevealBottomShelf: Bool = false
    @State private var shouldShowMetaData: Bool = false
    @FocusState private var focus: ButtonType?

    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            if self.settings.loadMediaBackgroundArt {
                MediaBackgroundView(
                    media: self.media,
                    streamingService: self.streamingService,
                    shouldBlurBackground: $shouldBackgroundBlur
                )
            }

            // Content
            ScrollView {
                // Logo and basic metadata
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MediaLogoView(media: self.media, streamingService: self.streamingService)
                        .background(alignment: .bottom) { // Subtle black shadow
                            if self.settings.loadMediaBackgroundArt {
                                let titleShadowSize = 800.0
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .black, location: 0),
                                                .init(color: .black.opacity(0), location: 1)
                                            ]),
                                            center: UnitPoint(x: 0.5, y: 0.5),
                                            startRadius: 0,
                                            endRadius: titleShadowSize
                                        )
                                        .opacity(0.9)
                                    )
                                    .frame(width: titleShadowSize * 2, height: titleShadowSize * 2)
                                    .offset(y: titleShadowSize)
                            }
                        }
                }
                .padding(.top)
                .frame(height: 350)

                // Play buttons
                PlayNavigationView(
                    navigation: $navigation,
                    media: media,
                    mediaSources: self.mediaSources,
                    streamingService: self.streamingService
                )
                .id("Play-button-view")
                .focused($focus, equals: .play)

                // Metadata
                HStack(alignment: .top) {
                    MediaOverview(media: self.media)
                        .focused($focus, equals: .overview)
                    MediaMetadata(media: self.media)
                        .focused($focus, equals: .metadata)
                }

                // Special features
                SpecialFeaturesView(navigation: self.$navigation, streamingService: self.streamingService, media: self.media)
                    .focused($focus, equals: .specialFeatures)

                // People
                if !self.media.people.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("People")
                            .font(.title3.bold())
                            .foregroundStyle(self.theme.currentTheme.header1)
                            .padding(.top)
                        PeopleBrowserView(people: self.media.people, streamingService: streamingService)
                            .focused($focus, equals: .people)
                    }
                }
            }
            .scrollClipDisabled()
            .padding(32)
            .offset(y: shouldRevealBottomShelf ? 0 : 500)
            .animation(.spring(.smooth), value: shouldRevealBottomShelf)
        }
        .ignoresSafeArea()
        .navigationDestination(for: MoviePlayerViewModel.self) { vm in
            MoviePlayerView(vm: vm, navigation: $navigation)
        }
        .colorScheme(self.settings.loadMediaBackgroundArt ? .dark : self.theme.currentTheme.colorScheme)
        .defaultFocus($focus, .play, priority: .userInitiated)
        .onChange(of: self.focus) { _, newValue in
            switch newValue {
            case .play:
                self.shouldRevealBottomShelf = false
                self.shouldBackgroundBlur = false
            case .metadata, .overview, .people, .specialFeatures:
                self.shouldRevealBottomShelf = true
                self.shouldBackgroundBlur = true
            case nil: break
            }
        }
    }
}

// MARK: Play button
fileprivate struct PlayNavigationView: View {
    private let media: any MediaProtocol
    private let streamingService: PlayerProviding & MediaImageProviding
    private var title: String
    private let mediaSources: [any MediaSourceProtocol]

    @Binding var navigation: NavigationPath

    @Environment(SettingsModel.self) var settings: SettingsModel

    init(
        navigation: Binding<NavigationPath>,
        media: any MediaProtocol,
        mediaSources: [any MediaSourceProtocol],
        streamingService: PlayerProviding & MediaImageProviding
    ) {
        self._navigation = navigation
        self.media = media
        self.streamingService = streamingService
        self.title = media.title
        self.mediaSources = mediaSources
    }

    var body: some View {
        // Single source button and menu
        if mediaSources.count == 1 {
            let mediaSource = self.mediaSources[0]
            // Single item that's unwatched - show button
            if mediaSource.startPoint == 0 {
                Button {
                    self.navigation.append(
                        MoviePlayerViewModel(
                            settingsModel: self.settings,
                            streamingService: self.streamingService,
                            media: self.media,
                            mediaSource: mediaSource,
                            startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1)
                        )
                    )
                }
                label: { Label(self.title, systemImage: "play.fill") }
                    .accessibilityLabel("Play button")
            }
            // Single item that's partially watched - show streamlined menu
            else {
                Menu("\(Image(systemName: "play")) \(title)") {
                    Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint) }
                    label: {
                        Label("Resume \(media.title)", systemImage: "play.fill")
                        Text("Continue from \(String(duration: mediaSource.startPoint))")
                    }
                    Button { navigateToPlayer(for: mediaSource, startPoint: .zero) }
                    label: { Label("Restart \(media.title)", systemImage: "memories") }
                }
                .accessibilityLabel("Play button menu")
            }
        }
        // Multiple media sources
        else {
            // If there are multiple sources but all unwatched, show only "play" options that start from beginning
            if (mediaSources.allSatisfy { $0.startPoint == 0 }) {
                Menu("\(Image(systemName: "play")) \(title)") {
                    ForEach(mediaSources, id: \.id) { mediaSource in
                        Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint) }
                        label: { Label(mediaSource.name, systemImage: "play.fill") }
                            .id(mediaSource.id)
                    }
                }
                .accessibilityLabel("Play button menu")
            }
            // If there's any that are somewhat played, present options to restart
            else {
                Menu("\(Image(systemName: "play")) \(title)") {
                    Section("Resume") {
                        ForEach(mediaSources, id: \.id) { mediaSource in
                            if mediaSource.startPoint != 0 {
                                Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint)
                                } label: {
                                    Label(mediaSource.name, systemImage: "play.fill")
                                    Text("Continue from \(String(duration: mediaSource.startPoint))")
                                }
                                .id(mediaSource.id)
                            }
                        }
                    }
                    Section("Restart") {
                        ForEach(mediaSources, id: \.id) { mediaSource in
                            Button { navigateToPlayer(for: mediaSource, startPoint: .zero) }
                            label: { Label(mediaSource.name, systemImage: "memories") }
                                .id(mediaSource.id)
                        }
                    }
                }
                .accessibilityLabel("Play button menu")
            }
        }
    }

    func navigateToPlayer(for mediaSource: any MediaSourceProtocol, startPoint: TimeInterval) {
        self.navigation.append(
            MoviePlayerViewModel(
                settingsModel: self.settings,
                streamingService: self.streamingService,
                media: media,
                mediaSource: mediaSource,
                startTime: CMTimeMakeWithSeconds(startPoint, preferredTimescale: 1)
            )
        )
    }
}

/// Types of buttons available on the `MovieDetailView`
fileprivate enum ButtonType: Hashable {
    case play
    case overview
    case metadata
    case people
    case specialFeatures
}
