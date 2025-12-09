//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State var library: any LibraryProtocol
    let streamingService: StreamingServiceProtocol
    let cardWidth = CGFloat(200)
    let cardSpacing = CGFloat(50)
    
    public var body: some View {
        ScrollView {
            switch library.media {
            case .unloaded, .waiting:
                ProgressView()
            case .error(let err):
                Text("Error: \(err.localizedDescription)")
                    .foregroundStyle(.red)
                    .padding(.vertical)
            case .available(let allMedia):
                if !allMedia.isEmpty {
                    let columns = [
                        GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: cardSpacing)
                    ]
                    LazyVGrid(columns: columns, spacing: cardSpacing) {
                        ForEach(allMedia) { media in
                            NavigationLink(destination: DetailMediaView(media: media, streamingService: streamingService)) {
                                MediaCard(media: media, streamingService: streamingService)
                                    .frame(width: cardWidth, height: 370)
                            }
                            .buttonStyle(.card)
                        }
                    }
                } else {
                    VStack(alignment: .center) {
                        Text("This library appears to be empty")
                        Text("Collections, playlists, and music aren't supported")
                            .opacity(0.5)
                    }
                }
            }
        }
    }
}
