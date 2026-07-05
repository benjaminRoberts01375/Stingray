//
//  MediaMetadata.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import SwiftUI

public struct MediaLogoView: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme
    
    @State private var logoOpacity: Double
    
    public let media: any MediaMetadataProtocol
    public let logoImageURL: URL?
    
    /// Displays the logo for some media type
    /// - Parameters:
    ///   - media: Media to display the logo for
    ///   - streamingService: Streaming service to load image from
    public init(media: any MediaMetadataProtocol, streamingService: MediaImageProviding) {
        self.logoOpacity = 0
        self.media = media
        self.logoImageURL = streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
    }
    
    public var body: some View {
        VStack(spacing: 15) {
            if logoImageURL != nil && !self.settings.replaceLogosWithText {
                AsyncImage(url: logoImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(logoOpacity)
                        .animation(.easeOut(duration: 0.5), value: logoOpacity)
                        .onAppear { logoOpacity = 1 }
                }
                placeholder: { EmptyView() }
                    .frame(width: 400)
            }
            else {
                Text(self.media.title)
                    .font(.title)
                    .bold()
                    .foregroundStyle(self.theme.currentTheme.header1)
            }
            if !self.media.tagline.isEmpty {
                Text(media.tagline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 800, alignment: .center)
            }
            MediaLogoHeader(media: self.media)
        }
    }
}

/// Shows very basic metadata 
public struct MediaLogoHeader: View {
    /// Media to display info about
    public let media: any MediaMetadataProtocol

    public var body: some View {
        if self.media.maturity != nil || self.media.releaseDate != nil || !self.media.genres.isEmpty || self.media.duration != nil {
            let items: [String] = [
                media.maturity,
                media.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                media.genres.isEmpty ? nil : media.genres.prefix(3).joined(separator: ", "),
                media.duration?.roundedTime()
            ].compactMap { $0 }
            
            Text(items.joined(separator: " • "))
        }
        else { EmptyView() }
    }
}
