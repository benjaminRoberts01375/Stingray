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
struct DetailMediaView: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    
    @State private var shouldBackgroundBlur: Bool = false
    @State private var shouldRevealBottomShelf: Bool = false
    @State private var shouldShowMetaData: Bool = false
    @FocusState private var focus: ButtonType?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MediaBackgroundView(
                media: media,
                backgroundImageURL: streamingService.getImageURL(imageType: .backdrop, mediaID: media.id, width: 0),
                shouldBlurBackground: $shouldBackgroundBlur
            )
            
            VStack {
                // Basic movie/series data
                Button { shouldShowMetaData = true }
                label: {
                    MediaLogoView(media: media, logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0))
                        .focused($focus, equals: .metadata)
                }
                .buttonStyle(.plain)
                .padding(.top)
                .frame(height: 150)
                .focusable({
                    switch focus {
                    case .play:
                        return true
                    default:
                        return false
                    }
                }())
                
                // Play buttons
                HStack {
                    switch media.mediaType {
                    case .collections:
                        EmptyView()
                    case .movies(let sources):
                        ForEach(sources, id: \.id) { source in
                            MovieNavigationView(mediaSource: source, streamingService: streamingService, focus: $focus)
                        }
                    case .tv(let seasons):
                        if let seasons = seasons, let episode = Self.getNextUp(from: seasons) ?? seasons.first?.episodes.first {
                            TVEpisodeNavigationView(seasons: seasons, streamingService: streamingService, episode: episode, focus: $focus)
                        } else {
                            ProgressView("Loading seasons...")
                        }
                    }
                }
                .focusable({
                    switch focus {
                    case .play, .metadata, .season:
                        return true
                    default:
                        return false
                    }
                }())
                
                // TV Episodes
                ScrollView {
                    switch media.mediaType {
                    case .tv(let seasons):
                        if let seasons, seasons.flatMap(\.episodes).count > 1 {
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
                                
                                ScrollView(.horizontal) {
                                    LazyHStack {
                                        EpisodeSelectorView(
                                            media: media,
                                            seasons: seasons,
                                            streamingService: streamingService,
                                            focus: $focus
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
                    default: EmptyView()
                    }
                }
                .scrollClipDisabled()
            }
            .offset(y: shouldRevealBottomShelf ? 0 : 700)
            .background(alignment: .bottom) {
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
        .onChange(of: focus) { _, newValue in
            switch newValue {
            case .media, .season:
                self.shouldBackgroundBlur = true
                self.shouldRevealBottomShelf = true
            case .metadata, .play:
                self.shouldBackgroundBlur = false
                self.shouldRevealBottomShelf = false
            case nil:
                break
            }
        }
        .onAppear { focus = .play }
    }
    
    static func getNextUp(from seasons: [any TVSeasonProtocol]) -> (any TVEpisodeProtocol)? {
        let allEpisodes = seasons.flatMap(\.episodes)
        guard let mostRecentEpisode = (allEpisodes.enumerated().max { previousEpisode, currentEpisode in
            previousEpisode.element.lastPlayed ?? .distantPast < currentEpisode.element.lastPlayed ?? .distantPast
        }),
              let mostRecentMediaSource = mostRecentEpisode.element.mediaSources.first
        else { return allEpisodes.first }
        
        if let durationTicks = mostRecentMediaSource.durationTicks,
           Double(mostRecentMediaSource.startTicks) < 0.9 * Double(durationTicks) ||
            mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
            return mostRecentEpisode.element
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
            if media.imageTags.thumbnail != nil {
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
}

// MARK: Movie play buttons
fileprivate struct MovieNavigationView: View {
    let mediaSource: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    
    var body: some View {
        NavigationLink {
            PlayerView(
                vm: PlayerViewModel(
                    mediaSource: mediaSource,
                    startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                    streamingService: streamingService,
                    seasons: nil
                )
            )
            .id(mediaSource.id)
        } label: {
            if mediaSource.startTicks > 0 {
                Text("Play \(mediaSource.name) - \(String(ticks: mediaSource.startTicks))")
            } else {
                Text("Play \(mediaSource.name)")
            }
        }
        .focused($focus, equals: .play)
    }
}

// MARK: Episode play buttons
fileprivate struct TVEpisodeNavigationView: View {
    let seasons: [any TVSeasonProtocol]
    let streamingService: any StreamingServiceProtocol
    let episode: any TVEpisodeProtocol
    
    @FocusState.Binding var focus: ButtonType?
    
    var body: some View {
        if let mediaSource = episode.mediaSources.first {
            // Always restart episode button
            NavigationLink {
                PlayerView(
                    vm: PlayerViewModel(
                        mediaSource: mediaSource,
                        startTime: .zero,
                        streamingService: streamingService,
                        seasons: seasons
                    )
                )
            } label: {
                Text("\(mediaSource.startTicks == 0 ? "Play" : "Restart") \(episode.title)")
            }
            .focused($focus, equals: .play)
            
            // If the next episode to play already has progress
            if mediaSource.startTicks != 0 {
                NavigationLink {
                    PlayerView(
                        vm: PlayerViewModel(
                            mediaSource: mediaSource,
                            startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                            streamingService: streamingService,
                            seasons: seasons
                        )
                    )
                } label: {
                    Text("Resume \(episode.title)")
                }
                .focused($focus, equals: .play)
            }
        } else {
            Text("Error loading episode")
                .foregroundStyle(.red)
        }
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
                let isActiveSeason: Bool = {
                    switch focus {
                    case .media(let mediaID):
                        return season.episodes.contains { $0.id == mediaID }
                    case .season, nil:
                        // Maintain the last focused season's background when focus is nil
                        return season.id == lastFocusedSeasonID
                    default:
                        return false
                    }
                }()
                
                if isActiveSeason {
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
                case .play, .metadata:
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
                        focus: $focus
                    )
                }
            }
        }
    }
}

fileprivate struct EpisodeNavigationView: View {
    let mediaID: String
    let mediaSource: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    let seasons: [any TVSeasonProtocol]
    let episode: any TVEpisodeProtocol
    
    var body: some View {
        NavigationLink {
            PlayerView(
                vm: (
                    PlayerViewModel(
                        mediaSource: mediaSource,
                        startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                        streamingService: streamingService,
                        seasons: seasons
                    )
                )
            )
            .id(mediaSource.id)
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

fileprivate struct EpisodeView: View {
    let media: any MediaProtocol
    let source: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    let seasons: [any TVSeasonProtocol]
    let episode: any TVEpisodeProtocol
    
    @FocusState.Binding var focus: ButtonType?
    @FocusState private var isFocused: Bool?
    @State var showDetails = false
    
    var body: some View {
        VStack {
            EpisodeNavigationView(
                mediaID: media.id,
                mediaSource: source,
                streamingService: streamingService,
                seasons: seasons,
                episode: episode
            )
            .frame(width: 400, height: 325)
            .focused($focus, equals: .media(episode.id))
            .focused($isFocused, equals: true)
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
                        .fill(Color.white.opacity(isFocused ?? false ? 0.1 : 0))
                }
                .padding(-16)
            }
            .buttonStyle(.plain)
            .focused($isFocused, equals: true)
            .animation(.easeOut(duration: 0.5), value: isFocused)
            .padding(.top, isFocused ?? false ? 16 : 0)
        }
    }
}

// MARK: Fullscreen Metadata
fileprivate struct MediaMetadataView: View {
    let media: any MediaProtocol
    private let logoImageURL: URL?
    private let streamingService: any StreamingServiceProtocol
    
    init(media: any MediaProtocol, streamingService: any StreamingServiceProtocol) {
        self.media = media
        self.logoImageURL = streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
        self.streamingService = streamingService
    }
    
    var body: some View {
        VStack {
            VStack {
                MediaLogoView(media: media, logoImageURL: logoImageURL)
                    .padding(.bottom)
                Text(media.description == "" ? "No description" : media.description)
            }
            .frame(width: 1000)
            Spacer()
            VStack {
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
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .scrollClipDisabled(true)
            }
            .frame(minWidth: 400)
        }
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
                    .aspectRatio(contentMode: .fit)
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
        VStack {
            ZStack {
                if let blurHash = episode.blurHashes?.getBlurHash(for: .primary),
                   let blurImage = UIImage(blurHash: blurHash, size: .init(width: 48, height: 27)) {
                    Image(uiImage: blurImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                }
                if let url = streamingService.getImageURL(imageType: .primary, mediaID: episode.id, width: 800) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .animation(.easeOut(duration: 0.5), value: imageOpacity)
                            .onAppear { imageOpacity = 1 }
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
        }
    }
}

fileprivate enum ButtonType: Hashable {
    case play
    case season(String)
    case media(String)
    case metadata
}
