//
//  MediaCardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import BlurHashKit
import SwiftUI

public struct MediaCard: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme

    @State private var showError: Bool = false

    @Binding public var navigation: NavigationPath

    public static let cardSize = CGSize(width: 200, height: 370)

    public let media: any MediaRepresentableProtocol
    public let url: URL?
    public let reserveTextSpace: Bool
    public let size: CGSize

    /// Creates a button based on the media's available art. This button navigates to the media's detail view
    /// - Parameters:
    ///   - media: Media to display and navigate on
    ///   - streamingService: Streaming service to derrive URLs from
    ///   - navigation: The app's `NavigationPath`
    ///   - reserveTextSpace: Allow the MediaCard to reserve the maximum amount of space for text
    ///   - size: Visual size of the card. Defaults to `cardSize`.
    /// - Note: While navigation is optional, this is purely for display purposes and should be filled in.
    public init(
        media: any MediaRepresentableProtocol,
        streamingService: MediaImageProviding,
        navigation: Binding<NavigationPath>? = nil,
        reserveTextSpace: Bool = true,
        size: CGSize = MediaCard.cardSize
    ) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 400)
        self._navigation = navigation ?? .constant(NavigationPath())
        self.reserveTextSpace = reserveTextSpace
        self.size = size
    }

    public var body: some View {
        Button {
            if let media = self.media as? (any MediaProtocol) { // Shortcut
                self.navigation.append(AnyMedia(media: media))
                return
            }
            self.navigation.append(self.media)
        }
        label: {
            VStack(spacing: 0) {
                if self.settings.loadThumbnailArt {
                    if media.imageTags?.primary != nil {
                        AsyncBlurImage(
                            blurHash: self.media.imageBlurHashes?.primary,
                            blurSize: CGSize(width: 20, height: 30),
                            imageURL: self.url,
                            scaleType: .fill
                        )
                    }
                    else { MediaCardNoImage() }
                    Spacer(minLength: 0)
                    Text(self.media.title)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: self.reserveTextSpace)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2)
                        .padding(5)
                        .frame(minHeight: 50)
                        .offset(y: -5)
                    Spacer(minLength: 0)
                }
                else {
                    Spacer(minLength: 0)
                    Text(self.media.title)
                        .font(.system(size: 30))
                        .bold()
                        .multilineTextAlignment(.center)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2)
                        .padding(.horizontal)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: self.size.width, height: self.size.height)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
    }
}

public struct MediaCardNoImage: View {
    public var body: some View {
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
