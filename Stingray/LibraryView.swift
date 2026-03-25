//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State var library: any LibraryProtocol
    
    @Binding var navigation: NavigationPath
    
    let streamingService: StreamingServiceProtocol
    let cardWidth = CGFloat(200)
    let cardSpacing = CGFloat(50)
    
    public var body: some View {
        ScrollView {
            switch library.media {
            case .unloaded, .waiting:
                ProgressView()
            case .error(let err):
                ErrorView(error: err, summary: "The server formatted the library's media unexpectedly.")
            case .available(let allMedia), .complete(let allMedia):
                if !allMedia.isEmpty {
                    MediaGridView(allMedia: allMedia, streamingService: streamingService, navigation: $navigation)
                } else {
                    VStack(alignment: .center) {
                        Text("This library appears to be empty.")
                        Text("Media types like collections, playlists, and music aren't yet supported.")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            LibraryInfoView(library: self.library)
                .padding(.top)
        }
    }
}

public struct MediaGridView: View {
    static let cardSpacing = 50.0
    let allMedia: [any MediaProtocol]
    let streamingService: any StreamingServiceProtocol
    
    @Binding public var navigation: NavigationPath
    
    public var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: MediaCard.cardSize.width, maximum: MediaCard.cardSize.height), spacing: Self.cardSpacing)
        ]
        LazyVGrid(columns: columns, spacing: Self.cardSpacing) {
            ForEach(allMedia, id: \.id) { media in
                MediaCard(media: media, streamingService: streamingService) { navigation.append(AnyMedia(media: media)) }
            }
        }
    }
}

/// Displays some high-level info about libraries.
public struct LibraryInfoView: View {
    /// Library to display info for.
    public let library: any LibraryProtocol
    
    public var body: some View {
        HStack(spacing: 0) {
            switch self.library.media { // Only display a ProgressView while downloading content.
            case .waiting, .unloaded, .available: ProgressView()
            default: EmptyView()
            }
            
            switch self.library.media {
            case .available(let media), .complete(let media): Text("\(media.count) Items")
            default: Text("0 Items")
            }
        }
        .foregroundStyle(.tertiary)
    }
}
