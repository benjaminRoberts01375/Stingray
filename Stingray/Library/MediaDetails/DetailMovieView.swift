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
    
    init (media: MediaModel, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.backgroundImageURL = streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken ?? "", imageType: .backdrop, imageID: media.id, width: 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if media.ImageTags.thumbnail != nil {
                    AsyncImage(url: backgroundImageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                            .clipped()
                    } placeholder: {
                        if let blurHash = media.imageBlurHashes?.getBlurHash(for: .thumb),
                           let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 32)) {
                            Image(uiImage: blurImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                                .clipped()
                        } else {
                            MediaCardLoading()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
    }
}
