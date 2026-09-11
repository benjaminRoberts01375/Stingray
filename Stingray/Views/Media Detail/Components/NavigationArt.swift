//
//  NavigationArt.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import BlurHashKit
import SwiftUI

// MARK: Episode Art
/// Thumbnail art for an episode or special feature, falling back to a large title when poster art is turned off.
public struct MediaArtView: View {
    /// Content to draw artwork for
    private let media: any Displayable
    /// Title shown when artwork is disabled
    private let title: String
    /// Artwork URL, resolved once at init
    private let imageURL: URL?

    @Environment(ThemeModel.self) private var theme
    @Environment(SettingsModel.self) private var settings
    /// Unused. `AsyncBlurImage` owns the fade-in
    @State private var imageOpacity: Double = 0

    /// Episode artwork
    /// - Parameters:
    ///   - media: Content to show artwork for
    ///   - streamingService: Streaming service used to resolve the artwork URL
    ///   - title: Title to show instead when poster art is disabled
    public init(media: any Displayable, streamingService: any MediaImageProviding, title: String) {
        self.media = media
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
