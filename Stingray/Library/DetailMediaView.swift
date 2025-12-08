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
    let backgroundImageURL: URL?
    let logoImageURL: URL?
    let streamingService: StreamingServiceProtocol
    @State private var logoOpacity: Double = 0
    @State private var showMetadata: Bool = false
    @FocusState private var focus: ButtonType?
    @State private var shouldBlurBackground: Bool = false
    private let titleShadowSize: CGFloat = 800
    
    init (media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.streamingService = streamingService
        self.backgroundImageURL = streamingService.getImageURL(imageType: .backdrop, imageID: media.id, width: 0)
        self.logoImageURL = streamingService.getImageURL(imageType: .logo, imageID: media.id, width: 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
                MediaBackgroundView(media: media, backgroundImageURL: backgroundImageURL, shouldBlurBackground: $shouldBlurBackground)
            VStack(alignment: .center, spacing: 15) {
                Spacer()
                
                // Basic movie/series data
                Button {
                    showMetadata = true
                } label: {
                    MediaLogoView(media: media, logoImageURL: logoImageURL)
                }
                .buttonStyle(.plain)
                .padding(.vertical)
                .focused($focus, equals: .metadata)
                
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
                        if let seasons = seasons {
                            TVNextEpisodeView(seasons: seasons, streamingService: streamingService, focus: $focus)
                        }
                    }
                }
                
                // Show episodes if series
                switch media.mediaType {
                case .tv(let seasons): // Show TV episodes
                    if let seasons = seasons {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.horizontal) {
                                EpisodeSelectorView(media: media, logoImageURL: logoImageURL, seasons: seasons, streamingService: streamingService, focus: $focus)
                            }
                            .scrollClipDisabled()
                            .padding(40)
                            .ignoresSafeArea()
                            .task {
                                if let nextEpisodeID = TVNextEpisodeView.getNextUp(from: seasons)?.id {
                                    scrollProxy.scrollTo(nextEpisodeID, anchor: .center)
                                }
                            }
                        }
                    }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .offset(y: focus == .media ? 0 : 550)
            .animation(.smooth(duration: 0.4), value: focus)
            .background(alignment: .bottom) {
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
        .toolbar(.hidden, for: .tabBar)
        .task { focus = .play }
        .onChange(of: focus) { _, newValue in
            switch focus {
            case .play, .metadata:
                shouldBlurBackground = false
            case .media, nil:
                shouldBlurBackground = true
            }
        }
        .fullScreenCover(isPresented: $showMetadata) {
            MediaMetadataView(media: media, streamingService: streamingService)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

fileprivate struct MovieNavigationView: View {
    let mediaSource: any MediaSourceProtocol
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    
    var body: some View {
        NavigationLink {
            PlayerView(
                vm: PlayerViewModel(
                    selectedAudioID: mediaSource.audioStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.audioStreams.first?.id ?? 1),
                    selectedVideoID: mediaSource.videoStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.videoStreams.first?.id ?? 1),
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
            }
            if media.ImageTags.thumbnail != nil {
                AsyncImage(url: backgroundImageURL) { image in
                    image
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .opacity(backgroundOpacity)
                        .animation(.easeOut(duration: 0.5), value: backgroundOpacity)
                        .onAppear {
                            backgroundOpacity = 1
                        }
                } placeholder: {
                    EmptyView()
                }
            }
            // Blurry background
            Color.clear
                .background(.ultraThinMaterial.opacity(shouldBlurBackground ? 1 : 0))
                .animation(.smooth(duration: 0.4), value: shouldBlurBackground)
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
                        .onAppear {
                            logoOpacity = 1
                        }
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

// MARK: Next episode selector
fileprivate struct TVNextEpisodeView: View {
    let seasons: [any TVSeasonProtocol]
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    
    static func getNextUp(from seasons: [any TVSeasonProtocol]) -> (any TVEpisodeProtocol)? {
        let allEpisodes = seasons.flatMap(\.episodes)
        guard let mostRecentEpisode = (allEpisodes.enumerated().max { $0.element.lastPlayed ?? .distantPast < $1.element.lastPlayed ?? .distantPast }),
              let mostRecentMediaSource = mostRecentEpisode.element.mediaSources.first
        else { return allEpisodes.first }
        
        if let durationTicks = mostRecentMediaSource.durationTicks,
           Double(mostRecentMediaSource.startTicks) < 0.9 * Double(durationTicks) ||
            mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
            return mostRecentEpisode.element
        }
        
        return allEpisodes[mostRecentEpisode.offset + 1]
    }
    
    var body: some View {
        if let nextEpisode = Self.getNextUp(from: seasons), let mediaSource = nextEpisode.mediaSources.first {
            
            // Always restart episode button
            NavigationLink {
                PlayerView(
                    vm: PlayerViewModel(
                        selectedSubtitleID: mediaSource.subtitleStreams.first(where: { $0.isDefault })?.id ?? mediaSource.subtitleStreams.first?.id,
                        selectedAudioID: mediaSource.audioStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.audioStreams.first?.id ?? 1),
                        selectedVideoID: mediaSource.videoStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.videoStreams.first?.id ?? 1),
                        mediaSource: mediaSource,
                        startTime: .zero,
                        streamingService: streamingService,
                        seasons: seasons
                    )
                )
            } label: {
                Text("\(mediaSource.startTicks == 0 ? "Play" : "Restart") \(nextEpisode.title)")
            }
            .focused($focus, equals: .play)
            
            // If the next episode to play already has progress
            if mediaSource.startTicks != 0 {
                NavigationLink {
                    PlayerView(
                        vm: PlayerViewModel(
                            selectedSubtitleID: mediaSource.subtitleStreams.first(where: { $0.isDefault })?.id ?? mediaSource.subtitleStreams.first?.id,
                            selectedAudioID: mediaSource.audioStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.audioStreams.first?.id ?? 1),
                            selectedVideoID: mediaSource.videoStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.videoStreams.first?.id ?? 1),
                            mediaSource: mediaSource,
                            startTime: CMTimeMakeWithSeconds(Double(mediaSource.startTicks / 10_000_000), preferredTimescale: 1),
                            streamingService: streamingService,
                            seasons: seasons
                        )
                    )
                } label: {
                    Text("Resume \(nextEpisode.title)")
                }
                .focused($focus, equals: .play)
            }
        }
    }
}

// MARK: Episode selector
fileprivate struct EpisodeSelectorView: View {
    let media: any MediaProtocol
    let logoImageURL: URL?
    
    let seasons: [any TVSeasonProtocol]
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focus: ButtonType?
    
    var body: some View {
        HStack {
            ForEach(seasons, id: \.id) { season in
                ForEach(season.episodes, id: \.id) { episode in
                    if let source = episode.mediaSources.first {
                        EpisodeView(logoImageURL: logoImageURL, media: media, source: source, streamingService: streamingService, seasons: seasons, episode: episode, focus: $focus)
                    }
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
                        selectedSubtitleID: mediaSource.subtitleStreams.first(where: { $0.isDefault })?.id ?? mediaSource.subtitleStreams.first?.id,
                        selectedAudioID: mediaSource.audioStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.audioStreams.first?.id ?? 1),
                        selectedVideoID: mediaSource.videoStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.videoStreams.first?.id ?? 1),
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
        }
        .buttonStyle(.card)
    }
}

fileprivate struct EpisodeView: View {
    let logoImageURL: URL?
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
            EpisodeNavigationView(mediaID: media.id, mediaSource: source, streamingService: streamingService, seasons: seasons, episode: episode)
                .frame(width: 400, height: 325)
                .focused($focus, equals: .media)
                .focused($isFocused, equals: true)
            
            if let overview = episode.overview {
                Button {
                    self.showDetails = true
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(overview)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 400, height: 200)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(isFocused ?? false ? 0.1 : 0))
                    }
                    .padding(-16)
                }
                .buttonStyle(.plain)
                .focused($isFocused, equals: true)
                .padding(.top, isFocused ?? false ? 16 : 0)
                .animation(.easeOut(duration: 0.4), value: isFocused)
                .sheet(isPresented: $showDetails) {
                    VStack {
                        Spacer()
                        MediaLogoView(media: media, logoImageURL: logoImageURL)
                            .padding()
                        Spacer()
                        Text(overview)
                            .padding()
                        Spacer()
                    }
                }
                .focused($focus, equals: .media)
            }
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
        self.logoImageURL = streamingService.getImageURL(imageType: .logo, imageID: media.id, width: 0)
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
            }
            if let url = streamingService.getImageURL(imageType: .primary, imageID: person.id, width: 0) {
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
                }
                if let url = streamingService.getImageURL(imageType: .primary, imageID: episode.id, width: 800) {
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
    case media
    case metadata
}
