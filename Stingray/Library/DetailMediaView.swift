//
//  DetailMediaView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

import BlurHashKit
import SwiftUI

struct DetailMediaView: View {
    let media: any MediaProtocol
    let backgroundImageURL: URL?
    let logoImageURL: URL?
    let streamingService: StreamingServiceProtocol
    @State private var backgroundOpacity: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var showMetadata: Bool = false
    @FocusState private var focusedSourceID: String?
    private let titleShadowSize: CGFloat = 800
    
    init (media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.streamingService = streamingService
        let accessToken = streamingService.accessToken ?? ""
        self.backgroundImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .backdrop, imageID: media.id, width: 0)
        self.logoImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .logo, imageID: media.id, width: 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if let blurHash = media.imageBlurHashes?.getBlurHash(for: .backdrop),
                   let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 18)) {
                    Image(uiImage: blurImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                        .clipped()
                }
                if media.ImageTags.thumbnail != nil {
                    AsyncImage(url: backgroundImageURL) { image in
                        image
                            .resizable()
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                            .opacity(backgroundOpacity)
                            .animation(.easeOut(duration: 0.5), value: backgroundOpacity)
                            .onAppear {
                                backgroundOpacity = 1
                            }
                    } placeholder: {
                        EmptyView()
                    }
                }
                VStack(alignment: .center, spacing: 15) {
                    Spacer()
                    Button {
                        showMetadata = true
                    } label: {
                        MediaLogoView(media: media, logoImageURL: logoImageURL)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical)
                    
                    HStack {
                        ForEach(media.mediaSources, id: \.id) { source in
                            NavigationLink(destination: PlayerView(streamingService: streamingService, mediaSource: source)) {
                                Text("Play \(source.name)")
                            }
                            .focused($focusedSourceID, equals: source.id)
                        }
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
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            focusedSourceID = media.mediaSources.first?.id
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

struct MediaLogoView: View {
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

struct MediaMetadataView: View {
    let media: any MediaProtocol
    private let logoImageURL: URL?
    private let streamingService: any StreamingServiceProtocol
    
    init(media: any MediaProtocol, streamingService: any StreamingServiceProtocol) {
        self.media = media
        self.logoImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken ?? "", imageType: .logo, imageID: media.id, width: 0)
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

struct ActorImage: View {
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
            if let accessToken = streamingService.accessToken, let url = streamingService.networkAPI.getMediaImageURL(accessToken: accessToken, imageType: .primary, imageID: person.id, width: 0) {
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
