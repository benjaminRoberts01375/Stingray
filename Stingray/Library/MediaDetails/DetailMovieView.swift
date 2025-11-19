//
//  DetailMovieView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/17/25.
//

import BlurHashKit
import SwiftUI

struct DetailMovieView: View {
    let media: MediaModel
    let backgroundImageURL: URL?
    let streamingService: StreamingServiceProtocol
    @State var opacity: Double
    @State private var showPlayer = false
    
    init (media: MediaModel, streamingService: StreamingServiceProtocol) {
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
                Button {
                    showPlayer = true
                } label: {
                    Text("Play \(media.title)")
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
