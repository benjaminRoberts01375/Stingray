//
//  DetailMovieView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

import BlurHashKit
import SwiftUI

struct DetailMovieView: View {
    let media: any MediaProtocol
    let backgroundImageURL: URL?
    let streamingService: StreamingServiceProtocol
    @State var opacity: Double
    @State private var showPlayer = false
    
    init (media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.streamingService = streamingService
        self.opacity = 0
        self.backgroundImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken ?? "", imageType: .backdrop, imageID: media.id, width: 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
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
                
                VStack {
                    NavigationLink(destination: PlayerView(streamingService: streamingService, media: media)) {
                        Text("Play \(media.title)")
                    }
                    Text("Keys:")
                    ForEach(media.mediaSources, id: \.id) { source in
                        ForEach(source.videoStreams, id: \.id) { video in
                            Text("\(video.displayTitle)")
                        }
                        ForEach(source.audioStreams, id: \.id) { audio in
                            Text("\(audio.displayTitle)")
                        }
                        ForEach(source.subtitleStreams, id: \.id) { subtitles in
                            Text("\(subtitles.displayTitle)")
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(streamingService: streamingService, media: media)
        }
    }
}
