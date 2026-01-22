//
//  MediaCardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import BlurHashKit
import SwiftUI

struct MediaCard: View {
    let media: any SlimMediaProtocol
    let url: URL?
    let videoRangeType: VideoRangeType?
    
    init(media: any SlimMediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 400)
        self.videoRangeType = nil
    }
    
    /// Initialize with full media to show HDR badges
    init(media: any MediaProtocol, streamingService: StreamingServiceProtocol) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 400)
        self.videoRangeType = media.hasHDR ? media.bestVideoRangeType : nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if media.imageTags.primary != nil {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        if let blurHash = media.imageBlurHashes?.getBlurHash(for: .primary),
                           let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 32)) {
                            Image(uiImage: blurImage)
                                .resizable()
                                .scaledToFill()
                                .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                        } else {
                            MediaCardLoading()
                        }
                    }
                } else {
                    MediaCardNoImage()
                }
                
                // HDR Badge overlay
                if let rangeType = videoRangeType {
                    HDRBadgeCompactView(videoRangeType: rangeType)
                        .padding(6)
                }
            }
            Text(media.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.horizontal, 5)
                .padding(.top, 5)
            Spacer()
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
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                Text("No image available")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
