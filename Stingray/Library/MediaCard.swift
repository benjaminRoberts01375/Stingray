//
//  MediaCard.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import BlurHashKit
import SwiftUI

struct MediaCard: View {
    let media: MediaModel
    let streamingService: StreamingServiceProtocol
    
    var body: some View {
        VStack(spacing: 0) {
            if media.ImageTags.primary != nil {
                AsyncImage(url: streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken ?? "", imageType: .primary, imageID: media.id)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    if let blurHash = media.imageBlurHashes?.getBlurHash(for: .primary),
                       let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 32)) {
                        Image(uiImage: blurImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        MediaCardLoading()
                    }
                }
                .aspectRatio(3/2, contentMode: .fit)
                .clipped()
            } else {
                MediaCardNoImage()
                    .aspectRatio(3/2, contentMode: .fit)
            }
            
            Text(media.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(5)
        }
        .id(media.id) // Stabilize view identity
    }
}

struct MediaCardLoading: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack {
                ProgressView()
                Text("Getting thumbnail")
            }
        }
    }
}

struct MediaCardNoImage: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No image available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
