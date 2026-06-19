//
//  DetailMediaView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

import AVKit
import BlurHashKit
import SwiftUI

// MARK: Main view
public struct TVShowDetailView: View {
    /// Media that contains content to play
    public let media: any MediaProtocol
    /// Streaming service the user is using
    public let streamingService: any StreamingServiceProtocol
    
    public let seasons: [any TVSeasonProtocol]
    
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
                    media: media,
                    backgroundImageURL: streamingService.getImageURL(imageType: .backdrop, mediaID: media.id, width: 0),
                    shouldBlurBackground: $shouldBackgroundBlur
                )
            }
            
            // Content
            ScrollView {
                // Logo and basic metadata
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MediaLogoView(
                        media: media,
                        logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
                    )
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
                    focus: $focus,
                    navigation: $navigation,
                    media: media,
                    seasons: self.seasons,
                    streamingService: streamingService
                )
                .disabled({
                    switch focus {
                    case .play, .overview, .season, .metadata, nil:
                        return false
                    default:
                        return true
                    }
                }())
                
                // TV Episodes
                if seasons.flatMap(\.episodes).count > 1 {
                    // Season selector
                    ScrollViewReader { svrProxy in
                        ScrollView(.horizontal) {
                            HStack {
                                SeasonSelectorView(
                                    seasons: seasons,
                                    streamingService: streamingService,
                                    focus: $focus,
                                    scrollProxy: svrProxy
                                )
                            }
                        }
                        .scrollClipDisabled()
                        .padding(32)
                        .opacity(shouldRevealBottomShelf ? 1 : 0)
                        
                        // Episode selector
                        ScrollView(.horizontal) {
                            LazyHStack {
                                EpisodeSelectorView(
                                    media: media,
                                    seasons: seasons,
                                    streamingService: streamingService,
                                    focus: $focus,
                                    navigation: $navigation
                                )
                            }
                        }
                        .task {
                            if let nextEpisodeID = seasons.nextUp()?.id {
                                svrProxy.scrollTo(nextEpisodeID, anchor: .center)
                            }
                        }
                        .scrollClipDisabled()
                        .padding(.horizontal)
                        .padding(.bottom)
                        .offset(y: shouldRevealBottomShelf ? 0 : -100)
                    }
                }
                
                // Metadata
                HStack(alignment: .top) {
                    MediaOverview(media: self.media)
                        .focused($focus, equals: .overview)
                    MediaMetadata(media: self.media)
                        .focused($focus, equals: .metadata)
                }
                
                // Special features
                SpecialFeaturesView(
                    navigation: self.$navigation,
                    streamingService: self.streamingService,
                    media: self.media
                )
                
                // People
                if !self.media.people.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("People")
                            .font(.title3.bold())
                            .foregroundStyle(self.theme.currentTheme.header1)
                            .padding(.top)
                        PeopleBrowserView(people: self.media.people, streamingService: streamingService)
                            .focused($focus, equals: .actor)
                    }
                }
            }
            .scrollClipDisabled()
            .padding(32)
            .offset(y: shouldRevealBottomShelf ? 0 : 500)
            .animation(.spring(.smooth), value: shouldRevealBottomShelf)
        }
        .ignoresSafeArea()
        .task { // Yep. I hate it too. Apple TVs are having issues selecting the play button if it changes type.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.focus = .play
            }
        }
        .onChange(of: focus) { _, newValue in
            switch newValue {
            case .media, .season, .overview, .metadata, .actor:
                self.shouldBackgroundBlur = true
                self.shouldRevealBottomShelf = true
            case .play:
                self.shouldBackgroundBlur = false
                self.shouldRevealBottomShelf = false
            case nil:
                break
            }
        }
        .navigationDestination(for: PlayerViewModel.self) { vm in
            PlayerView(vm: vm, navigation: $navigation)
        }
        .colorScheme(self.settings.loadMediaBackgroundArt ? .dark : self.theme.currentTheme.colorScheme)
    }
}

// MARK: Play button
fileprivate struct PlayNavigationView: View {
    private let media: any MediaProtocol
    private let streamingService: any StreamingServiceProtocol
    private var title: String
    private let mediaSources: [any MediaSourceProtocol]
    private let seasons: [any TVSeasonProtocol]
    
    @FocusState.Binding var focus: ButtonType?
    @Binding var navigation: NavigationPath
    
    @Environment(SettingsModel.self) var settings: SettingsModel
    
    init(
        focus: FocusState<ButtonType?>.Binding,
        navigation: Binding<NavigationPath>,
        media: any MediaProtocol,
        seasons: [any TVSeasonProtocol],
        streamingService: any StreamingServiceProtocol
    ) {
        self._focus = focus
        self._navigation = navigation
        self.media = media
        self.streamingService = streamingService
        self.seasons = seasons
        guard let nextEpisode = seasons.nextUp()
        else {
            self.title = "Error"
            self.mediaSources = []
            return
        }
        self.title = nextEpisode.title
        self.mediaSources = nextEpisode.mediaSources
    }
    
    var body: some View {
        Group {
            // Single source button and menu
            if mediaSources.count == 1 {
                let mediaSource = self.mediaSources[0]
                // Single item that's unwatched - show button
                if mediaSource.startPoint == 0 {
                    Button {
                        self.navigation.append(
                            PlayerViewModel(
                                media: media,
                                mediaSource: mediaSource,
                                startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1),
                                streamingService: self.streamingService,
                                seasons: self.seasons,
                                settingsModel: self.settings,
                            )
                        )
                    } label: { Label(self.title, systemImage: "play.fill") }
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
        .onAppear { self.focus = .play }
        .focused($focus, equals: .play)
        .id("Play-button")
        .defaultFocus($focus, .play, priority: .userInitiated)
    }
    
    func navigateToPlayer(for mediaSource: any MediaSourceProtocol, startPoint: TimeInterval) {
        self.navigation.append(
            PlayerViewModel(
                media: media,
                mediaSource: mediaSource,
                startTime: CMTimeMakeWithSeconds(startPoint, preferredTimescale: 1),
                streamingService: self.streamingService,
                seasons: self.seasons,
                settingsModel: self.settings
            )
        )
    }
}

// MARK: Season selector
fileprivate struct SeasonSelectorView: View {
    let seasons: [any TVSeasonProtocol]
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    @State private var lastFocusedSeasonID: String?
    let scrollProxy: ScrollViewProxy
    
    var body: some View {
        ForEach(seasons, id: \.id) { season in
            Button {
                if let firstEpisode = season.episodes.first {
                    // Scroll to the first episode of the season
                    withAnimation {
                        scrollProxy.scrollTo(firstEpisode.id, anchor: .center)
                    }
                    // Small delay to ensure the view is loaded before transferring focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.focus = .media(firstEpisode.id)
                    }
                }
            }
            label: { Text(season.title) }
            .padding(16)
            .background {
                if season.id == lastFocusedSeasonID {
                    Capsule()
                        .opacity(0.25)
                } else {
                    EmptyView()
                }
            }
            .padding(-16)
            .padding(.horizontal)
            .buttonStyle(.plain)
            .onMoveCommand { direction in
                if direction == .up { self.focus = .play }
            }
            .focused($focus, equals: .season(season.id))
            .disabled({
                switch focus {
                case .play, .overview, .metadata:
                    return true
                case .media(let mediaID):
                    return !season.episodes.contains { $0.id == mediaID }
                case nil:
                    return season.id != lastFocusedSeasonID
                case .season, .actor:
                    return false
                }
            }())
        }
        .onChange(of: focus) { _, newValue in
            // Track which season is active when focus changes
            switch newValue {
            case .media(let mediaID):
                if let season = seasons.first(where: { $0.episodes.contains { $0.id == mediaID } }) {
                    lastFocusedSeasonID = season.id
                }
            default:
                break
            }
        }
    }
}

// MARK: Episode selector
fileprivate struct EpisodeSelectorView: View {
    let media: any MediaProtocol
    let seasons: [any TVSeasonProtocol]
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    @Binding var navigation: NavigationPath
    
    var body: some View {
        ForEach(seasons, id: \.id) { season in
            ForEach(season.episodes, id: \.id) { episode in
                if let source = episode.mediaSources.first {
                    EpisodeView(
                        media: media,
                        source: source,
                        streamingService: streamingService,
                        seasons: seasons,
                        episode: episode,
                        focus: $focus,
                        navigation: $navigation
                    )
                }
            }
        }
    }
}

// MARK: Episode summary and navigation
fileprivate struct EpisodeView: View {
    let media: any MediaProtocol
    let source: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    let seasons: [any TVSeasonProtocol]
    let episode: any TVEpisodeProtocol
    
    @FocusState.Binding var focus: ButtonType?
    @Binding var navigation: NavigationPath
    
    @FocusState private var isFocused: Bool
    @State var showDetails = false
    
    var body: some View {
        VStack {
            // Episode thumbnail with navigation capabilities
            EpisodeNavigationView(
                media: media,
                mediaSource: source,
                streamingService: streamingService,
                seasons: seasons,
                episode: episode,
                navigation: $navigation
            )
            .focused($focus, equals: .media(episode.id))
            .focused($isFocused, equals: true)
            .offset(y: isFocused ? -16 : 0)
            .animation(.easeOut(duration: 0.5), value: isFocused)
            .onMoveCommand { direction in
                if direction == .up, let seasonID = (seasons.first { $0.episodes.contains { $0.id == episode.id } }?.id) {
                    self.focus = .season(seasonID)
                }
            }
            
            Button {
                self.showDetails = episode.overview != nil
            } label: {
                VStack(alignment: .leading) {
                    // Season and episode number
                    HStack(spacing: 0) {
                        if let season = (seasons.first { $0.episodes.contains { $0.id == episode.id } }) {
                            Text("\(season.title), Episode \(episode.episodeNumber)")
                        }
                        else { Text("Episode \(episode.episodeNumber)") }
                        Spacer()
                    }
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .opacity(episode.overview != nil ? 0.5 : 1)
                    
                    if let overview = episode.overview {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(overview)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .sheet(isPresented: $showDetails) {
                            VStack {
                                Spacer()
                                MediaLogoView(
                                    media: media,
                                    logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
                                )
                                .padding()
                                Spacer()
                                Text(overview)
                                    .padding()
                                Spacer()
                            }
                        }
                    } else {
                        Text("No description available")
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 400, height: 225)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(isFocused ? 0.1 : 0))
                }
                .padding(-16)
            }
            .buttonStyle(.plain)
            .focused($isFocused, equals: true)
            .focused($focus, equals: .media(episode.id))
        }
    }
}

// MARK: Episode thumbnail navigator
fileprivate struct EpisodeNavigationView: View {
    let media: any MediaProtocol
    let mediaSource: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    let seasons: [any TVSeasonProtocol]
    let episode: any TVEpisodeProtocol
    
    @Binding var navigation: NavigationPath
    
    @Environment(ThemeModel.self) var theme
    @Environment(SettingsModel.self) var settings: SettingsModel
    
    var body: some View {
        Button {
            navigation.append(
                PlayerViewModel(
                    media: media,
                    mediaSource: mediaSource,
                    startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1),
                    streamingService: streamingService,
                    seasons: seasons,
                    settingsModel: self.settings
                )
            )
        } label: {
            VStack(spacing: 0) {
                if !self.settings.loadThumbnailArt { Spacer(minLength: 0) }
                MediaArtView(media: self.episode, streamingService: streamingService, title: self.episode.title)
                if self.settings.loadThumbnailArt {
                    Spacer(minLength: 0)
                    Text(episode.title)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding()
                }
                Spacer(minLength: 0)
            }
            .frame(width: 400, height: 325)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
    }
}

/// Types of buttons available on the `DetailMediaView`
fileprivate enum ButtonType: Hashable {
    case play
    case season(String)
    case media(String)
    case overview
    case metadata
    case actor
}
