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
public struct DetailMediaView: View {
    /// Media that contains content to play
    let media: any MediaProtocol
    /// Streaming service the user is using
    let streamingService: any StreamingServiceProtocol
    
    @Binding var navigation: NavigationPath
    
    @State private var shouldBackgroundBlur: Bool = false
    @State private var shouldRevealBottomShelf: Bool = false
    @State private var shouldShowMetaData: Bool = false
    @FocusState private var focus: ButtonType?
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            MediaBackgroundView(
                media: media,
                backgroundImageURL: streamingService.getImageURL(imageType: .backdrop, mediaID: media.id, width: 0),
                shouldBlurBackground: $shouldBackgroundBlur
            )
            
            // Content
            ScrollView {
                // Logo and basic metadata
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MediaLogoView(
                        media: media,
                        logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
                    )
                }
                .padding(.top)
                .frame(height: 350)
                
                // Play buttons
                PlayNavigationView(focus: $focus, navigation: $navigation, media: media, streamingService: streamingService)
                .disabled({
                    switch focus {
                    case .play, .overview, .season, nil:
                        return false
                    default:
                        return true
                    }
                }())
                
                // TV Episodes
                switch media.mediaType {
                case .tv(let seasons):
                    if let seasons, seasons.flatMap(\.episodes).count > 1 {
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
                                if let nextEpisodeID = Self.getNextUp(from: seasons)?.id {
                                    svrProxy.scrollTo(nextEpisodeID, anchor: .center)
                                }
                            }
                            .scrollClipDisabled()
                            .padding(.horizontal)
                            .offset(y: shouldRevealBottomShelf ? 0 : -100)
                        }
                    }
                    
                default:
                    EmptyView()
                        .focusable(false)
                }
                
                // Metadata
                // Overview
                HStack(alignment: .top) {
                    Button {} label: {
                        VStack(alignment: .leading) {
                            if !media.description.isEmpty {
                                Text("Overview")
                                    .font(.headline.bold())
                                    .lineLimit(2)
                                Text(media.description)
                                    .multilineTextAlignment(.leading)
                            }
                            else {
                                Text("No description available")
                                    .opacity(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .focused($focus, equals: .overview)
                    // Ratings
                    Button {} label: {
                        VStack(alignment: .leading, spacing: 16) {
                            if !media.genres.isEmpty || media.releaseDate != nil || media.maturity != nil {
                                if !media.genres.isEmpty {
                                    VStack(alignment: .leading) {
                                        Text("Genres")
                                            .font(.headline.bold())
                                            .lineLimit(2)
                                        Text(media.genres.joined(separator: ", "))
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                if let releaseDate = media.releaseDate {
                                    VStack(alignment: .leading) {
                                        Text("Released")
                                            .font(.headline.bold())
                                            .lineLimit(2)
                                        Text(String(Calendar.current.component(.year, from: releaseDate)))
                                            .lineLimit(1)
                                    }
                                }
                                if let maturity = media.maturity {
                                    Text("Maturity")
                                        .font(.headline.bold())
                                        .lineLimit(1)
                                    Text(maturity)
                                        .lineLimit(1)
                                }
                            }
                            else {
                                Text("No metadata available")
                                    .opacity(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .focused($focus, equals: .overview)
                }
                .padding(.vertical, {
                    switch self.media.mediaType {
                    case .tv: 64
                    default: 0
                    }
                }())
                
                // Special features
                SpecialFeaturesView(streamingService: self.streamingService, media: self.media, navigation: self.$navigation)
                
                // People
                PeopleBrowserView(media: media, streamingService: streamingService)
                
            }
            .scrollClipDisabled()
            .padding(32)
            .offset(y: shouldRevealBottomShelf ? 0 : 500)
            .background(alignment: .bottom) { // Subtle black shadow
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
            case .media, .season, .overview:
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
    }
    
    static func getNextUp(from seasons: [any TVSeasonProtocol]) -> (any TVEpisodeProtocol)? {
        let allEpisodes = seasons.flatMap(\.episodes)
        // If the first episode hasn't been played suggest it
        if let firstEpisode = allEpisodes.first, firstEpisode.lastPlayed == nil {
            return firstEpisode
        }
        // Get the most recent episode
        guard let mostRecentEpisode = (allEpisodes.enumerated().max { previousEpisode, currentEpisode in
            return previousEpisode.element.lastPlayed ?? .distantPast < currentEpisode.element.lastPlayed ?? .distantPast
        }),
              let mostRecentMediaSource = mostRecentEpisode.element.mediaSources.first
        else { return allEpisodes.first } // failing getting the most recent, return the first episode
        
        // Watched previous episode all the way through
        if mostRecentMediaSource.startTicks == 0 {
            if mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
                return allEpisodes.first ?? mostRecentEpisode.element
            }
            return allEpisodes[mostRecentEpisode.offset + 1]
        }
        
        // Likely marked by Stingray that the user didn't finish
        if let durationTicks = mostRecentMediaSource.durationTicks,
           Double(mostRecentMediaSource.startTicks) < 0.9 * Double(durationTicks) {
            return mostRecentEpisode.element
        }
        
        // User finished the series, recommend the first episode again
        if mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
            return allEpisodes.first ?? mostRecentEpisode.element
        }
        return allEpisodes[mostRecentEpisode.offset + 1]
    }
}

// MARK: Background
fileprivate struct MediaBackgroundView: View {
    let media: any MediaProtocol
    let backgroundImageURL: URL?
    @State private var backgroundOpacity: Double = 0
    @Binding var shouldBlurBackground: Bool
    
    var body: some View {
        GeometryReader { geo in
            // Background image
            if let blurHash = media.imageBlurHashes?.getBlurHash(for: .backdrop),
               let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 18)) {
                Image(uiImage: blurImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .clipped()
                    .accessibilityHint("Placeholder image", isEnabled: false)
            }
            if backgroundImageURL != nil {
                AsyncImage(url: backgroundImageURL) { image in
                    image
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .opacity(backgroundOpacity)
                        .animation(.spring(.smooth), value: backgroundOpacity)
                        .onAppear { backgroundOpacity = 1 }
                } placeholder: {
                    EmptyView()
                }
            }
            // Blurry background
            Color.clear
                .background(.thinMaterial.opacity(shouldBlurBackground ? 1 : 0))
                .animation(.smooth(duration: 0.5), value: shouldBlurBackground)
        }
    }
}

// MARK: Movie logo and basics
fileprivate struct MediaLogoView: View {
    @State private var logoOpacity: Double = 0
    let media: any MediaProtocol
    let logoImageURL: URL?
    
    var body: some View {
        VStack(spacing: 15) {
            if logoImageURL != nil {
                AsyncImage(url: logoImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(logoOpacity)
                        .animation(.easeOut(duration: 0.5), value: logoOpacity)
                        .onAppear { logoOpacity = 1 }
                } placeholder: {
                    EmptyView()
                }
                .frame(width: 400)
            }
            if !media.tagline.isEmpty {
                Text(media.tagline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 800, alignment: .center)
            }
            MediaMetadataView(media: media)
        }
    }
}

// MARK: Movie metadata
public struct MediaMetadataView: View {
    /// Media to show metadata for
    let media: any MediaProtocol
    
    public var body: some View {
        if media.maturity != nil || media.releaseDate != nil || !media.genres.isEmpty || media.duration != nil {
            let items: [String] = [
                media.maturity,
                media.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                media.genres.isEmpty ? nil : media.genres.prefix(3).joined(separator: ", "),
                media.duration?.roundedTime()
            ].compactMap { $0 }
            
            Text(items.joined(separator: " • "))
        }
    }
}

// MARK: Play button
fileprivate struct PlayNavigationView: View {
    private let media: any MediaProtocol
    private let streamingService: any StreamingServiceProtocol
    private var title: String
    private let mediaSources: [any MediaSourceProtocol]
    private let seasons: [any TVSeasonProtocol]?
    
    @FocusState.Binding var focus: ButtonType?
    @Binding var navigation: NavigationPath
    
    init(
        focus: FocusState<ButtonType?>.Binding,
        navigation: Binding<NavigationPath>,
        media: any MediaProtocol,
        streamingService: any StreamingServiceProtocol
    ) {
        self._focus = focus
        self._navigation = navigation
        self.media = media
        self.streamingService = streamingService
        switch media.mediaType {
        case .movies(let sources):
            self.title = media.title
            self.mediaSources = sources
            self.seasons = nil
            
        case .tv(let seasons):
            guard let seasons = seasons,
                  let nextEpisode = DetailMediaView.getNextUp(from: seasons)
            else {
                self.title = "Error"
                self.mediaSources = []
                self.seasons = nil
                break
            }
            self.title = nextEpisode.title
            self.mediaSources = nextEpisode.mediaSources
            self.seasons = seasons
            
        default: // Collections
            self.title = "Unsupported"
            self.mediaSources = []
            self.seasons = nil
        }
    }
    
    var body: some View {
        Group {
            // Single source button and menu
            if mediaSources.count == 1 {
                let mediaSource = self.mediaSources[0]
                // Single item that's unwatched - show button
                if mediaSource.startTicks == 0 {
                    Button {
                        self.navigation.append(
                            PlayerViewModel(
                                media: media,
                                mediaSource: mediaSource,
                                startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                                streamingService: self.streamingService,
                                seasons: self.seasons
                            )
                        )
                    } label: { Label(self.title, systemImage: "play.fill") }
                        .accessibilityLabel("Play button")
                }
                // Single item that's partially watched - show streamlined menu
                else {
                    Menu("\(Image(systemName: "play")) \(title)") {
                        Button { navigateToPlayer(for: mediaSource, startTicks: mediaSource.startTicks) }
                        label: {
                            Label("Resume \(media.title)", systemImage: "play.fill")
                            Text("Continue from \(String(ticks: mediaSource.startTicks))")
                        }
                        Button { navigateToPlayer(for: mediaSource, startTicks: .zero) }
                        label: { Label("Restart \(media.title)", systemImage: "memories") }
                    }
                    .accessibilityLabel("Play button menu")
                }
            }
            // Multiple media sources
            else {
                // If there are multiple sources but all unwatched, show only "play" options that start from beginning
                if (mediaSources.allSatisfy { $0.startTicks == 0 }) {
                    Menu("\(Image(systemName: "play")) \(title)") {
                        ForEach(mediaSources, id: \.id) { mediaSource in
                            Button { navigateToPlayer(for: mediaSource, startTicks: mediaSource.startTicks) }
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
                                if mediaSource.startTicks != 0 {
                                    Button { navigateToPlayer(for: mediaSource, startTicks: mediaSource.startTicks)
                                    } label: {
                                        Label(mediaSource.name, systemImage: "play.fill")
                                        Text("Continue from \(String(ticks: mediaSource.startTicks))")
                                    }
                                    .id(mediaSource.id)
                                }
                            }
                        }
                        Section("Restart") {
                            ForEach(mediaSources, id: \.id) { mediaSource in
                                Button { navigateToPlayer(for: mediaSource, startTicks: .zero) }
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
    
    func navigateToPlayer(for mediaSource: any MediaSourceProtocol, startTicks: Int) {
        self.navigation.append(
            PlayerViewModel(
                media: media,
                mediaSource: mediaSource,
                startTime: CMTimeMakeWithSeconds(
                    Double(startTicks / 10_000_000), preferredTimescale: 1
                ),
                streamingService: self.streamingService,
                seasons: self.seasons
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
            } label: {
                Text("Season \(season.seasonNumber)")
            }
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
                case .play, .overview:
                    return true
                case .media(let mediaID):
                    return !season.episodes.contains { $0.id == mediaID }
                case nil:
                    return season.id != lastFocusedSeasonID
                case .season:
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
            .frame(width: 400, height: 325)
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
                            Text("Season \(season.seasonNumber), ")
                        }
                        Text("Episode \(episode.episodeNumber)")
                        Spacer()
                    }
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
                        Text("No Description Available")
                            .opacity(0.5)
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
    
    var body: some View {
        Button {
            navigation.append(
                PlayerViewModel(
                    media: media,
                    mediaSource: mediaSource,
                    startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                    streamingService: streamingService,
                    seasons: seasons
                )
            )
        } label: {
            VStack(spacing: 0) {
                EpisodeArtView(episode: episode, streamingService: streamingService)
                Text(episode.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding()
                Spacer(minLength: 0)
            }
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
    }
}

// MARK: Actor Photo
fileprivate struct ActorImage: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    let person: any MediaPersonProtocol
    @State private var imageOpacity: Double = 0
    
    var body: some View {
        ZStack {
            if let blurHash = media.imageBlurHashes?.getBlurHash(for: .backdrop),
               let blurImage = UIImage(blurHash: blurHash, size: .init(width: 30, height: 45)) {
                Image(uiImage: blurImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
            }
            if let url = streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 0) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }
}

// MARK: Episode Art
fileprivate struct EpisodeArtView: View {
    let episode: any TVEpisodeProtocol
    let streamingService: any StreamingServiceProtocol
    
    @State private var imageOpacity: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let blurHash = episode.blurHashes?.getBlurHash(for: .primary),
                   let blurImage = UIImage(blurHash: blurHash, size: .init(width: 48, height: 27)) {
                    Image(uiImage: blurImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                }
                if let url = streamingService.getImageURL(imageType: .primary, mediaID: episode.id, width: 800) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .animation(.easeOut(duration: 0.5), value: imageOpacity)
                            .onAppear { imageOpacity = 1 }
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }
}

// MARK: Actor browser
public struct PeopleBrowserView: View {
    // Media to pull people from
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    
    public var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(media.people, id: \.id) { person in
                    Button { /* Temp Workaround */ } label: {
                        VStack {
                            ActorImage(media: media, streamingService: streamingService, person: person)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(width: 300)
                            Text(person.name)
                                .multilineTextAlignment(.center)
                                .font(.headline)
                            Text(person.role)
                                .multilineTextAlignment(.center)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
        }
        .scrollClipDisabled()
    }
}

/// Types of buttons available on the `DetailMediaView`
fileprivate enum ButtonType: Hashable {
    case play
    case season(String)
    case media(String)
    case overview
}

public struct SpecialFeaturesView: View {
    let streamingService: any StreamingServiceProtocol
    let media: any MediaProtocol
    
    @Binding var navigation: NavigationPath
    
    public var body: some View {
        VStack {
            switch self.media.specialFeatures {
            case .unloaded:
                Color.clear
                    .task {
                        print("Attempting to get special features...")
                        do { try await self.streamingService.getSpecialFeatures(for: self.media) }
                        catch {}
                    }
            case .loading:
                ProgressView("Loading special features...")
            case .loaded(let rows):
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SpecialFeaturesRow(streamingService: streamingService, rowData: row, navigation: $navigation)
                }
            }
        }
    }
}

public struct SpecialFeaturesRow: View {
    let streamingService: any StreamingServiceProtocol
    let rowData: [any SpecialFeaturesProtocol]
    let title: String
    
    @Binding var navigation: NavigationPath
    
    init(
        streamingService: any StreamingServiceProtocol,
        rowData: [any SpecialFeaturesProtocol],
        navigation: Binding<NavigationPath>
    ) {
        self.streamingService = streamingService
        self.rowData = rowData
        self.title = rowData[0].featureType
        self._navigation = navigation
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(self.title)
                .font(.title.bold())
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(rowData, id: \.id) { specialFeature in
                        Text(specialFeature.title)
                    }
                }
            }
        }
    }
}
