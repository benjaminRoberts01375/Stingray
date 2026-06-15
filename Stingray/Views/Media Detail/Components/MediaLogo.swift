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
    
    @State private var logoOpacity: Double = 0
    
    public let media: any MediaProtocol
    public let logoImageURL: URL?
    
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
            if !media.tagline.isEmpty {
                Text(media.tagline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 800, alignment: .center)
            }
            if media.maturity != nil || media.releaseDate != nil || !media.genres.isEmpty || media.duration != nil {
                let items: [String] = [
                    media.maturity,
                    media.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                    media.genres.isEmpty ? nil : media.genres.prefix(3).joined(separator: ", "),
                    media.duration?.roundedTime()
                ].compactMap { $0 }
                
                Text(items.joined(separator: " • "))
            }
        }
    }
}
