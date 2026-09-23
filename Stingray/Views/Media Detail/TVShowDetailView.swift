//
//  TVShowDetailView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

import AVKit
import BlurHashKit
import SwiftUI

// MARK: Main view
/// A show's detail screen: logo over backdrop art, with a season selector, episode strip, metadata, and cast on the bottom shelf.
public struct TVShowDetailView: View {
    /// Media that contains content to play
    public let media: any MediaProtocol
    /// Streaming service the user is using
    public let streamingService: PlayerProviding & MediaImageProviding & MediaProviding

    /// Season download progress. The episode strip stays hidden until this is `.loaded`
    public let seasons: TVSeasonsAvailable

    /// App navigation, used to push the player
    @Binding public var navigation: NavigationPath

    /// Blurs the backdrop once focus leaves the play button
    @State private var shouldBackgroundBlur: Bool = false
    /// Slides the episode and metadata shelf up once focus leaves the play button
    @State private var shouldRevealBottomShelf: Bool = false
    /// Which element has focus. Drives the blur, the shelf, and season/episode coordination
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
                    MediaLogoView(media: media, streamingService: self.streamingService)
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
                    seasons: self.seasons,
                    streamingService: streamingService
                )
                .id("play-button-view")
                .focused($focus, equals: .play)
                .disabled({
                    switch self.focus {
                    case .play, .overview, .season, .metadata, nil:
                        return false
                    default:
                        return true
                    }
                }())

                // TV Episodes
                switch self.seasons {
                case .loaded(let seasons):
                    // Season selector
                    ScrollViewReader { svrProxy in
                        ScrollView(.horizontal) {
                            HStack {
                                SeasonSelectorView(
                                    seasons: seasons,
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
                default: EmptyView()
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
                            .focused($focus, equals: .person)
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
        .defaultFocus($focus, .play)
        .onChange(of: focus) { _, newValue in
            switch newValue {
            case .media, .season, .overview, .metadata, .person:
                self.shouldBackgroundBlur = true
                self.shouldRevealBottomShelf = true
            case .play:
                self.shouldBackgroundBlur = false
                self.shouldRevealBottomShelf = false
            case nil: break
            }
        }
        .navigationDestination(for: TVPlayerViewModel.self) { vm in
            TVPlayerView(vm: vm, navigation: $navigation)
        }
        .colorScheme(self.settings.loadMediaBackgroundArt ? .dark : self.theme.currentTheme.colorScheme)
    }
}

// MARK: Play button
/// The play control, targeting whichever episode is up next. Shows a spinner until seasons finish downloading, since the next episode
/// isn't known before then. Resolves "next up" once at init.
fileprivate struct PlayNavigationView: View {
    /// Show being played
    private let media: any MediaProtocol
    /// Streaming service used to start playback
    private let streamingService: PlayerProviding & MediaImageProviding
    /// Button label, taken from the next episode's title
    private var title: String
    /// Sources for the next episode. Empty until seasons load
    private let mediaSources: [any MediaSourceProtocol]
    /// Season download progress
    private let seasons: TVSeasonsAvailable

    /// App navigation, used to push the player
    @Binding var navigation: NavigationPath

    @Environment(SettingsModel.self) var settings: SettingsModel

    /// Creates the play control for a show, resolving the next episode to watch.
    /// - Parameters:
    ///   - navigation: App navigation, used to push the player
    ///   - media: Show to play
    ///   - seasonsAvailable: Season download progress. Anything but `.loaded` renders a spinner
    ///   - streamingService: Streaming service used to start playback
    init(
        navigation: Binding<NavigationPath>,
        media: any MediaProtocol,
        seasons seasonsAvailable: TVSeasonsAvailable,
        streamingService: PlayerProviding & MediaImageProviding
    ) {
        self._navigation = navigation
        self.media = media
        self.streamingService = streamingService
        self.seasons = seasonsAvailable
        switch seasonsAvailable {
        case .unloaded, .loading:
            self.mediaSources = []
            self.title = String(localized: "Loading...")
        case .loaded(let seasons):
            guard let nextEpisode = seasons.nextUp()
            else {
                self.title = String(localized: "Loading...")
                self.mediaSources = []
                break
            }
            self.title = nextEpisode.title
            self.mediaSources = nextEpisode.mediaSources
        }
    }

    var body: some View {
        Group {
            switch self.seasons {
            case .unloaded, .loading:
                Button { }
                label: {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                }
            default:
                // Single source button and menu
                if mediaSources.count == 1 {
                    let mediaSource = self.mediaSources[0]
                    // Single item that's unwatched - show button
                    if mediaSource.startPoint == 0 {
                        Button {
                            switch self.seasons {
                            case .loaded(let seasons):
                                self.navigation.append(
                                    TVPlayerViewModel(
                                        media: media,
                                        mediaSource: mediaSource,
                                        startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1),
                                        streamingService: self.streamingService,
                                        seasons: seasons,
                                        settingsModel: self.settings,
                                    )
                                )
                            default: break
                            }
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
        }
    }

    /// Pushes the TV player for one episode source at a given position. No-op until seasons have loaded.
    /// - Parameters:
    ///   - mediaSource: Episode source to play
    ///   - startPoint: Where to begin, in seconds. Pass `.zero` to restart
    func navigateToPlayer(for mediaSource: any MediaSourceProtocol, startPoint: TimeInterval) {
        switch self.seasons {
        case .unloaded, .loading: break
        case .loaded(let seasons):
            self.navigation.append(
                TVPlayerViewModel(
                    media: media,
                    mediaSource: mediaSource,
                    startTime: CMTimeMakeWithSeconds(startPoint, preferredTimescale: 1),
                    streamingService: self.streamingService,
                    seasons: seasons,
                    settingsModel: self.settings
                )
            )
        }
    }
}

// MARK: Season selector
/// The season tabs above the episode strip. Selecting a season scrolls the episode strip to its first episode and hands focus over. Only
/// the active season stays focusable, so left/right movement walks episodes rather than jumping between season tabs.
fileprivate struct SeasonSelectorView: View {
    /// Seasons to offer, in display order
    let seasons: [any TVSeasonProtocol]

    /// Shared focus state, used to move focus into the episode strip
    @FocusState.Binding var focus: ButtonType?
    /// Season containing the most recently focused episode, used to highlight the active tab
    @State private var lastFocusedSeasonID: String?
    /// Proxy for the episode strip, used to scroll to a season's first episode
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
                    }
                    else { EmptyView() }
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
                    case .season, .person:
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
/// Every episode of every season, flattened into one continuous strip.
fileprivate struct EpisodeSelectorView: View {
    /// Show the episodes belong to
    let media: any MediaProtocol
    /// Seasons to flatten, in display order
    let seasons: [any TVSeasonProtocol]
    /// Streaming service used for artwork and playback
    let streamingService: PlayerProviding & MediaImageProviding

    /// Shared focus state, so the season tabs can track the active episode
    @FocusState.Binding var focus: ButtonType?
    /// App navigation, used to push the player
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
/// One episode in the strip: its thumbnail above a tappable summary that expands into a sheet.
fileprivate struct EpisodeView: View {
    /// Show the episode belongs to
    let media: any MediaProtocol
    /// Source to play when the thumbnail is selected
    let source: any MediaSourceProtocol
    /// Streaming service used for artwork and playback
    let streamingService: PlayerProviding & MediaImageProviding
    /// Every season, used to label this episode with its season name
    let seasons: [any TVSeasonProtocol]
    /// Episode being represented
    let episode: any TVEpisodeProtocol

    /// Shared focus state, used to move focus up to the season tabs
    @FocusState.Binding var focus: ButtonType?
    /// App navigation, used to push the player
    @Binding var navigation: NavigationPath

    /// Whether this specific card has focus, which lifts it and tints its summary
    @FocusState private var isFocused: Bool
    /// Controls the full description sheet. Only opens when the episode has an overview
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

            Button { self.showDetails = episode.overview != nil }
            label: {
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
                                MediaLogoView(media: media, streamingService: self.streamingService)
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
/// An episode's thumbnail as a card button that starts playback from its saved resume point.
fileprivate struct EpisodeNavigationView: View {
    /// Show the episode belongs to
    let media: any MediaProtocol
    /// Source to play
    let mediaSource: any MediaSourceProtocol
    /// Streaming service used for artwork and playback
    let streamingService: PlayerProviding & MediaImageProviding
    /// Every season, handed to the player for autoplay and the episode picker
    let seasons: [any TVSeasonProtocol]
    /// Episode being represented
    let episode: any TVEpisodeProtocol

    /// App navigation, used to push the player
    @Binding var navigation: NavigationPath

    @Environment(ThemeModel.self) var theme
    @Environment(SettingsModel.self) var settings: SettingsModel

    var body: some View {
        Button {
            navigation.append(
                TVPlayerViewModel(
                    media: media,
                    mediaSource: mediaSource,
                    startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1),
                    streamingService: self.streamingService,
                    seasons: seasons,
                    settingsModel: self.settings
                )
            )
        } label: {
            VStack(spacing: 0) {
                MediaArtView(media: self.episode, streamingService: self.streamingService, title: self.episode.title)
                    .clipped()
                if self.settings.loadThumbnailArt {
                    Text(self.episode.title)
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

/// Types of buttons available on the `TVShowDetailView`
///
/// Focus on `.play` keeps the bottom shelf hidden and the background sharp; focus on anything else reveals the shelf and blurs the
/// background. The associated IDs let focus move to one specific season or episode rather than the row as a whole.
fileprivate enum ButtonType: Hashable {
    /// The play button or play menu
    case play
    /// A season tab, identified by season ID
    case season(String)
    /// An episode card, identified by episode ID
    case media(String)
    /// The description panel
    case overview
    /// The genres, release, and maturity panel
    case metadata
    /// The cast and crew row
    case person
}
