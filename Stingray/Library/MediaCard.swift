//
//  MediaCard.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

struct MediaCard: View {
    @State var media: MediaModel
    let streamingServicee: StreamingServiceProtocol
    
    var body: some View {
        VStack {
            AsyncImage(url: streamingServicee.networkAPI.getMediaImageURL(accessToken: streamingServicee.accessToken ?? "", imageType: .primary, imageID: media.id)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .aspectRatio(2/3, contentMode: .fit)
            Text(media.title)
                .lineLimit(2)
        }
    }
}
