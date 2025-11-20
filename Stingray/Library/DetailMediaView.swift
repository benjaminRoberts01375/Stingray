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
            ZStack(alignment: .center) {
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
                    VStack(alignment: .center) {
                        AsyncImage(url: logoImageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(width: 400)
                    }
                    Text(media.tagline)
                        .italic()
                        .frame(maxWidth: 800, alignment: .center)
                    NavigationLink(destination: PlayerView(streamingService: streamingService, media: media)) {
                        Text("Play \(media.title)")
                    }
                    HStack(spacing: 0) {
                        if let maturity = media.maturity {
                            Text("\(maturity) • ")
                        }
                        if let date = media.releaseDate {
                            Text("\(String(Calendar.current.component(.year, from: date))) • ")
                        }
                        if media.genres.count > 0 {
                            Text(media.genres.prefix(3).joined(separator: ", "))
                        }
                    }
                }
                .shadow(color: .black, radius: 10)
                .padding()
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(streamingService: streamingService, media: media)
        }
    }
}
