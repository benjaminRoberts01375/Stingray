//
//  MediaCard.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

struct MediaCard: View {
    let media: MediaModel
    let streamingService: StreamingServiceProtocol
    
    var body: some View {
        VStack(spacing: 0) {
            AsyncImage(url: streamingService.networkAPI.getMediaImageURL(accessToken: streamingService.accessToken ?? "", imageType: .primary, imageID: media.id)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                MediaCardLoading()
            }
            .aspectRatio(3/2, contentMode: .fit)
            .clipped()
            
            Text(media.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(5)
        }
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
