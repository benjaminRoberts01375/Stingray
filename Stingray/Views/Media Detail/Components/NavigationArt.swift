//
//  RichPlayButton.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import BlurHashKit
import SwiftUI

// MARK: Episode Art
public struct MediaArtView: View {
    private let media: any Displayable
    private let streamingService: any StreamingServiceProtocol
    private let title: String
    private let imageURL: URL?
    
    @Environment(ThemeModel.self) private var theme
    @Environment(SettingsModel.self) private var settings
    @State private var imageOpacity: Double = 0
    
    public init(media: any Displayable, streamingService: any StreamingServiceProtocol, title: String) {
        self.media = media
        self.streamingService = streamingService
        self.title = title
        self.imageURL = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 800)
    }
    
    public var body: some View {
        if self.settings.loadThumbnailArt {
            AsyncBlurImage(
                blurHash: self.media.imageBlurHashes?.primary,
                blurSize: CGSize(width: 48, height: 27),
                imageURL: self.imageURL,
                scaleType: .fit
            )
        }
        else {
            Text(self.title)
                .font(.system(size: 35))
                .bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(self.theme.currentTheme.header2)
                .padding(.horizontal)
        }
    }
}
