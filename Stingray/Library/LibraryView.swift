//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State var library: LibraryModel
    let streamingService: StreamingServiceProtocol
    let cardWidth = CGFloat(200)
    let cardSpacing = CGFloat(50)
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                switch library.media {
                case .unloaded, .waiting:
                    ProgressView()
                case .error(let err):
                    Text("Error: \(err.localizedDescription)")
                        .foregroundStyle(.red)
                        .padding(.vertical)
                case .available(let allMedia):
                    let columns = [
                        GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: cardSpacing)
                    ]
                    LazyVGrid(columns: columns, spacing: cardSpacing) {
                        ForEach(allMedia) { media in
                            NavigationLink(value: media) {
                                MediaCard(media: media, streamingService: streamingService)
                                    .frame(width: cardWidth, height: 370)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
            .navigationDestination(for: MediaModel.self) { media in
                DetailMovieView(media: media, streamingService: streamingService)
            }
        }
    }
}
