//
//  DetailMediaView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

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
    @FocusState private var focusedEpisodeID: String?
    @State private var shouldBlurBackground: Bool = false
    private let titleShadowSize: CGFloat = 800
    
    init (media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.streamingService = streamingService
        let accessToken = streamingService.accessToken
        self.backgroundImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .backdrop, imageID: media.id, width: 0)
        self.logoImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .logo, imageID: media.id, width: 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                MediaBackgroundView(media: media, backgroundImageURL: backgroundImageURL, shouldBlurBackground: $shouldBlurBackground, size: geometry.size)
            }
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
                
                // All versions of a movie
                HStack {
                    ForEach(media.mediaSources, id: \.id) { source in
                        NavigationLink {
                            PlayerView(streamingService: streamingService, mediaSource: source)
                                .id(source.id)
                        } label: {
                            if source.startTicks > 0 {
                                Text("Play \(source.name) - \(String(ticks: source.startTicks))")
                            } else {
                                Text("Play \(source.name)")
                            }
                            
                        }
                    }
                }
                
                // Show episodes if series
                switch media.mediaType {
                case .tv(let seasons): // Show TV episodes
                    if let seasons = seasons {
                        ScrollView(.horizontal) {
                            EpisodeSelectorView(seasons: seasons, accessToken: streamingService.accessToken, streamingService: streamingService, focusedEpisodeID: $focusedEpisodeID)
                        }
                        .scrollClipDisabled()
                        .padding(40)
                        .ignoresSafeArea()
                    }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
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
            .animation(.easeOut(duration: 0.5), value: shouldBlurBackground)
        }
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: focusedEpisodeID) { _, newValue in
            shouldBlurBackground = newValue != nil
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

// MARK: Background
fileprivate struct MediaBackgroundView: View {
    let media: any MediaProtocol
    let backgroundImageURL: URL?
    @State private var backgroundOpacity: Double = 0
    @Binding var shouldBlurBackground: Bool
    let size: CGSize
    
    var body: some View {
        // Background image
        if let blurHash = media.imageBlurHashes?.getBlurHash(for: .backdrop),
           let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 18)) {
            Image(uiImage: blurImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
        }
        if media.ImageTags.thumbnail != nil {
            AsyncImage(url: backgroundImageURL) { image in
                image
                    .resizable()
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
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
            .animation(.easeOut(duration: 0.5), value: shouldBlurBackground)
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

// MARK: Episode selector
fileprivate struct EpisodeSelectorView: View {
    let seasons: [any TVSeasonProtocol]
    let accessToken: String
    let streamingService: any StreamingServiceProtocol
    
    @FocusState.Binding var focusedEpisodeID: String?
    
    var body: some View {
        HStack {
            ForEach(seasons, id: \.id) { season in
                ForEach(season.episodes, id: \.id) { episode in
                    if let source = episode.mediaSources.first {
                        NavigationLink {
                            PlayerView(streamingService: streamingService, mediaSource: source, seasons: seasons)
                                .id(source.id)
                        } label: {
                            VStack(spacing: 0) {
                                EpisodeArtView(episode: episode, accessToken: accessToken, networkAPI: streamingService.networkAPI)
                                Text(episode.title)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding()
                                Spacer(minLength: 0)
                            }
                            .frame(width: 350, height: 300)
                        }
                        .buttonStyle(.card)
                        .focused($focusedEpisodeID, equals: episode.id)
                    }
                }
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
        self.logoImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken, imageType: .logo, imageID: media.id, width: 0)
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
            if let url = streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken, imageType: .primary, imageID: person.id, width: 0) {
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
    let accessToken: String
    let networkAPI: any AdvancedNetworkProtocol
    
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
                if let url = networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .primary, imageID: episode.id, width: 800) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .animation(.easeOut(duration: 0.5), value: imageOpacity)
                            .onAppear {
                                print("Showing episode image for \(episode.title): \(url.absoluteString)")
                                imageOpacity = 1
                            }
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
        }
    }
}
