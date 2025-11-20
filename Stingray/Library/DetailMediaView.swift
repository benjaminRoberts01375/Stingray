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
    @State var opacity: Double
    @State private var showPlayer = false
    private let titleShadowSize: CGFloat = 800
    
    init (media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.streamingService = streamingService
        self.opacity = 0
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
                            .opacity(opacity)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    opacity = 1
                                }
                            }
                    } placeholder: {
                        EmptyView()
                    }
                }
                VStack(alignment: .center, spacing: 15) {
                    Spacer()
                    if logoImageURL != nil {
                        AsyncImage(url: logoImageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
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
                    NavigationLink(destination: PlayerView(streamingService: streamingService, media: media)) {
                        Text("Play \(media.title)")
                    }
                    if media.maturity != nil || media.releaseDate != nil || !media.genres.isEmpty {
                        let items: [String] = [
                            media.maturity,
                            media.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                            media.genres.isEmpty ? nil : media.genres.prefix(3).joined(separator: ", ")
                        ].compactMap { $0 }
                        
                        Text(items.joined(separator: " • "))
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
                            .opacity(0.8)
                        )
                        .frame(width: titleShadowSize * 2, height: titleShadowSize * 2)
                        .offset(y: titleShadowSize)
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
    }
}
